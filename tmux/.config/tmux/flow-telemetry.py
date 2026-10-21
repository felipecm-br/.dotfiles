#!/usr/bin/env python3
"""
flow-telemetry.py — Evidence-based personal telemetry & deep work flow engine.
Calculates uninterrupted focus duration, human response latency, review durations,
and renders the Cockpit HUD summary and hourly deep work heatmap.
"""

import sys
import os
import argparse
import datetime
import math
import statistics
from typing import List, Tuple, Dict, Any, Optional


def fmt_secs(value: Optional[float]) -> str:
    """Seconds for display, or an em dash when there is no data (never a made-up number)."""
    return "—" if value is None else f"{value:.0f}s"

def resolve_colors_toml() -> str:
    helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme-helper.sh")
    try:
        res = subprocess.run([helper, "--path"], capture_output=True, text=True, timeout=1)
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    return os.path.expanduser("~/.config/tmux/colors.toml")

def load_theme_colors() -> Dict[str, str]:
    colors = {
        "cyan": "#83c092",
        "yellow": "#dbbc7f",
        "red": "#e67e80",
        "green": "#a7c080",
        "magenta": "#d699b6",
        "blue": "#7fbbb3",
        "darkgray": "#4f5b58",
        "gray": "#7a8478",
        "fg": "#d3c6aa",
    }
    colors_toml = resolve_colors_toml()
    if os.path.exists(colors_toml):
        try:
            with open(colors_toml, "r") as f:
                for line in f:
                    line = line.strip()
                    if "=" in line and not line.startswith("#"):
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k in colors and v.startswith("#"):
                            colors[k] = v
        except Exception:
            pass
    return colors

def hex_to_ansi(hex_code: str) -> str:
    hex_code = hex_code.lstrip("#")
    if len(hex_code) != 6:
        return "\033[36m"
    try:
        r = int(hex_code[0:2], 16)
        g = int(hex_code[2:4], 16)
        b = int(hex_code[4:6], 16)
        return f"\033[38;2;{r};{g};{b}m"
    except Exception:
        return "\033[36m"

class TelemetryEngine:
    def __init__(self, tsv_path: Optional[str] = None):
        if not tsv_path:
            tsv_path = os.path.expanduser("~/.local/state/flow/events.tsv")
        self.tsv_path = tsv_path
        self.events: List[Tuple[int, str, str, str]] = []
        self.today_start = datetime.datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        ).timestamp()
        self.load_events()

    def load_events(self):
        if not os.path.exists(self.tsv_path):
            return
        try:
            with open(self.tsv_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    parts = line.rstrip("\r\n").split("\t")
                    if len(parts) >= 2:
                        try:
                            ts = int(parts[0])
                            if ts >= self.today_start:
                                ev = parts[1]
                                target = parts[2] if len(parts) > 2 else ""
                                extra = parts[3] if len(parts) > 3 else ""
                                self.events.append((ts, ev, target, extra))
                        except ValueError:
                            continue
        except Exception:
            pass

    def compute_flow_clusters(self, max_gap_seconds: int = 1200) -> List[Tuple[int, int]]:
        """Cluster timestamps into contiguous flow sessions (default max gap 20 min)."""
        ts_list = sorted([e[0] for e in self.events])
        if not ts_list:
            return []
        clusters = []
        c_start = ts_list[0]
        c_end = ts_list[0]
        for t in ts_list[1:]:
            if t - c_end <= max_gap_seconds:
                c_end = t
            else:
                clusters.append((c_start, c_end))
                c_start = t
                c_end = t
        clusters.append((c_start, c_end))
        return clusters

    def get_metrics(self, canonical: bool = False) -> Dict[str, Any]:
        clusters = self.compute_flow_clusters(max_gap_seconds=1200)
        total_flow_seconds = 0
        longest_flow_seconds = 0
        for s, e in clusters:
            dur = max(e - s, 300) # At least 5m per active cluster
            total_flow_seconds += dur
            if dur > longest_flow_seconds:
                longest_flow_seconds = dur

        def seconds(extra: str) -> Optional[int]:
            try:
                return int(extra[:-1]) if extra.endswith("s") else None
            except ValueError:
                return None

        reply_latencies: List[int] = []   # agent question -> human reply
        review_latencies: List[int] = []  # task finished -> review opened
        review_durations: List[int] = []
        review_rates: List[float] = []    # lines reviewed per minute
        review_size: Dict[str, int] = {}
        for _, ev, target, extra in self.events:
            if ev == "human_reply" and (s := seconds(extra)) is not None:
                reply_latencies.append(s)
            elif ev == "review_start" and (s := seconds(extra)) is not None:
                review_latencies.append(s)
            elif ev == "review_size" and extra.isdigit():
                review_size[target] = int(extra)
            elif ev == "review_end" and (s := seconds(extra)) is not None:
                review_durations.append(s)
                # Pair with the diff size logged when this review opened.
                lines = review_size.pop(target, 0)
                if s > 0 and lines > 0:
                    review_rates.append(lines * 60 / s)

        # Hourly distribution (08h - 23h)
        hourly_counts = [0] * 24
        for ts, _, _, _ in self.events:
            dt = datetime.datetime.fromtimestamp(ts)
            hourly_counts[dt.hour] += 1

        review_count = len(review_durations)
        metrics: Dict[str, Any] = {
            "total_flow_seconds": total_flow_seconds,
            "flow_str": f"{total_flow_seconds // 3600}h{(total_flow_seconds % 3600) // 60:02d}min",
            "longest_flow_seconds": longest_flow_seconds,
            "clusters_count": len(clusters),
            "review_count": review_count,
            "avg_review_duration": sum(review_durations) / review_count if review_count else None,
            "median_review_latency": statistics.median(review_latencies) if review_latencies else None,
            "median_review_rate": statistics.median(review_rates) if review_rates else None,
            "reply_latencies": reply_latencies,
            "review_latencies": review_latencies,
            "review_durations": review_durations,
            "review_lines_per_minute": review_rates,
            "max_idle_seconds": max(reply_latencies + review_latencies, default=None),
            "hourly_counts": hourly_counts,
        }
        if canonical:
            # Demo values for screenshots (--canonical only); real runs never show them.
            metrics.update(
                flow_str="4h12min",
                review_count=8,
                avg_review_duration=92.0,
                median_review_latency=1.0,
                reply_latencies=[4, 5],
                max_idle_seconds=8,
            )

        if metrics["review_count"]:
            reviews_str = (
                f"{metrics['review_count']} revisões com média de "
                f"{round(metrics['avg_review_duration'])}s"
            )
        else:
            reviews_str = "nenhuma revisão registrada"
        max_idle = metrics["max_idle_seconds"]
        if max_idle is None:
            idle_str = "sem dados de espera de agente"
        elif max_idle <= 120:
            idle_str = "nenhum agente ficou ocioso > 2 min"
        else:
            idle_str = f"tempo máx de espera de agente foi {round(max_idle / 60)} min"
        metrics["summary_text"] = (
            f"Hoje você teve {metrics['flow_str']} de fluxo ininterrupto, "
            f"{reviews_str} e {idle_str}"
        )
        return metrics

    def render_summary(self, canonical: bool = False) -> str:
        metrics = self.get_metrics(canonical=canonical)
        return metrics["summary_text"]

    def render_hud_ansi(self, canonical: bool = False) -> str:
        colors = load_theme_colors()
        c_cyan = hex_to_ansi(colors["cyan"])
        c_yellow = hex_to_ansi(colors["yellow"])
        c_green = hex_to_ansi(colors["green"])
        c_magenta = hex_to_ansi(colors["magenta"])
        c_blue = hex_to_ansi(colors["blue"])
        c_dark = hex_to_ansi(colors["darkgray"])
        c_gray = hex_to_ansi(colors["gray"])
        c_reset = "\033[0m"
        c_bold = "\033[1m"
        c_dim = "\033[2m"

        metrics = self.get_metrics(canonical=canonical)
        hourly = metrics["hourly_counts"]

        # Build ASCII heatmap for hours 08 to 23
        header_hours = []
        block_chars = []
        for h in range(8, 24):
            header_hours.append(f"{h:02d}")
            count = hourly[h]
            if count == 0:
                block_chars.append(f"{c_dark}· {c_reset}")
            elif count < 6:
                block_chars.append(f"{c_cyan}░ {c_reset}")
            elif count < 18:
                block_chars.append(f"{c_green}▒ {c_reset}")
            elif count < 35:
                block_chars.append(f"{c_yellow}▓ {c_reset}")
            else:
                block_chars.append(f"{c_magenta}{c_bold}█ {c_reset}")

        line1_hours = f"  {c_dim}" + " ".join(header_hours) + f"{c_reset}"
        line2_blocks = "  " + "".join(block_chars)

        summary = metrics["summary_text"]
        replies = metrics["reply_latencies"]
        avg_reply = fmt_secs(sum(replies) / len(replies) if replies else None)
        max_reply = fmt_secs(max(replies) if replies else None)
        avg_rev = fmt_secs(metrics["avg_review_duration"])
        rev_count = metrics["review_count"]
        review_lag = fmt_secs(metrics["median_review_latency"])
        rate = metrics["median_review_rate"]
        rate_str = "—" if rate is None else f"{rate:.0f} linhas/min"

        out = []
        out.append(f"\n  {c_cyan}{c_bold}📊 Telemetria de Fluxo & Deep Work{c_reset}")
        out.append(f"  {c_dim}────────────────────────────────────────────────────────────{c_reset}")
        out.append(f"  {c_green}󰄬 {c_bold}{summary}{c_reset}")
        out.append(f"  {c_dim}────────────────────────────────────────────────────────────{c_reset}\n")
        out.append(f"  {c_yellow}{c_bold}󰓩 Heatmap de Concentração Horária (Hoje){c_reset}")
        out.append(line1_hours)
        out.append(line2_blocks)
        out.append(f"  {c_dim}Legenda: {c_dark}· Vazio  {c_cyan}░ Leve  {c_green}▒ Foco  {c_yellow}▓ Intenso  {c_magenta}█ Deep Work{c_reset}\n")
        out.append(f"  {c_blue}{c_bold}󰊢 Evidência Matemática & Latências{c_reset}")
        out.append(f"    • {c_yellow}Pergunta → Resposta (Humano):{c_reset}    méd {c_bold}{avg_reply}{c_reset} (máx {max_reply})")
        out.append(f"    • {c_cyan}Tarefa Concluída → Revisão:{c_reset}      mediana {c_bold}{review_lag}{c_reset}")
        out.append(f"    • {c_magenta}Duração Média de Revisão:{c_reset}       {c_bold}{avg_rev}{c_reset} ({rev_count} revisões)")
        out.append(f"    • {c_blue}Ritmo de Revisão:{c_reset}               mediana {c_bold}{rate_str}{c_reset}")
        out.append(f"    • {c_green}Sessões Ininterruptas de Fluxo:{c_reset} {c_bold}{metrics['flow_str']}{c_reset} ({max(metrics['clusters_count'], 1)} blocos)")
        out.append("")

        return "\n".join(out)

    def render_markdown(self, canonical: bool = False) -> str:
        metrics = self.get_metrics(canonical=canonical)
        hourly = metrics["hourly_counts"]
        summary = metrics["summary_text"]

        # Markdown Heatmap bar
        blocks = []
        for h in range(8, 24):
            count = hourly[h]
            if count == 0:
                b = "·"
            elif count < 6:
                b = "░"
            elif count < 18:
                b = "▒"
            elif count < 35:
                b = "▓"
            else:
                b = "█"
            blocks.append(f"`{h:02d}h` {b}")

        heatmap_str = " | ".join(blocks[:8]) + "\n" + " | ".join(blocks[8:])

        replies = metrics["reply_latencies"]
        avg_reply_v = sum(replies) / len(replies) if replies else None
        max_reply_v = max(replies) if replies else None
        lag_v = metrics["median_review_latency"]
        review_lags = metrics["review_latencies"]
        max_lag_v = max(review_lags) if review_lags else None
        avg_rev_v = metrics["avg_review_duration"]
        max_rev_v = max(metrics["review_durations"]) if metrics["review_durations"] else None
        idle_v = metrics["max_idle_seconds"]

        def status(value: Optional[float], limit: float) -> str:
            # Measured against the target; no data is reported as such, never as a pass.
            if value is None:
                return "— sem dados"
            return "✅ dentro da meta" if value < limit else "⚠️ acima da meta"

        cells = []
        for h in range(8, 24):
            val = hourly[h]
            if val == 0:
                cells.append("·")
            elif val < 6:
                cells.append("░")
            elif val < 18:
                cells.append("▒")
            elif val < 35:
                cells.append("▓")
            else:
                cells.append("█")
        table_row = " | ".join(cells)

        md = f"""### 📊 Telemetria Pessoal de Fluxo & Deep Work

> [!IMPORTANT]
> **Resumo Diário Baseado em Evidências:**  
> **{summary}**

#### 󰓩 Heatmap de Foco Horário (08h - 23h)

| 08h | 09h | 10h | 11h | 12h | 13h | 14h | 15h | 16h | 17h | 18h | 19h | 20h | 21h | 22h | 23h |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| {table_row} |

*Legenda: `·` Ocioso • `░` Atividade leve • `▒` Concentração • `▓` Foco contínuo • `█` Deep Work pleno*

#### 󰊢 Tabela de Evidência de Latências

| Métrica de Interação | Valor Médio | Limite Máximo | Meta Ergonomia | Status |
|:---|:---:|:---:|:---:|:---:|
| **Pergunta do Agente → Resposta do Operador** | **{fmt_secs(avg_reply_v)}** | {fmt_secs(max_reply_v)} | `< 15s` | {status(avg_reply_v, 15)} |
| **Término de Tarefa → Abertura do Lazygitrs** (mediana) | **{fmt_secs(lag_v)}** | {fmt_secs(max_lag_v)} | `< 30s` | {status(lag_v, 30)} |
| **Duração por Revisão** | **{fmt_secs(avg_rev_v)}** | {fmt_secs(max_rev_v)} | `< 100s` | {status(avg_rev_v, 100)} |
| **Tempo Ininterrupto em Estado de Fluxo** | **{metrics['flow_str']}** | — | `> 4h00min` | {"✅ dentro da meta" if metrics["total_flow_seconds"] > 4 * 3600 else "⚠️ abaixo da meta"} |
| **Ociosidade Máxima de Agente** | **{fmt_secs(idle_v)}** | — | `< 2 min` | {status(idle_v, 120)} |
"""
        return md


def main():
    parser = argparse.ArgumentParser(description="Flow State Telemetry Engine")
    parser.add_argument("--summary", action="store_true", help="Print single-line evidence summary")
    parser.add_argument("--hud", action="store_true", help="Print ANSI colored HUD view")
    parser.add_argument("--markdown", action="store_true", help="Print GitHub Flavored Markdown")
    parser.add_argument("--json", action="store_true", help="Print raw JSON metrics")
    parser.add_argument("--canonical", action="store_true", help="Format with benchmark canonical targets")
    parser.add_argument("--tsv", type=str, help="Custom events.tsv path", default=None)
    args = parser.parse_args()

    engine = TelemetryEngine(tsv_path=args.tsv)

    if args.summary:
        print(engine.render_summary(canonical=args.canonical))
    elif args.markdown:
        print(engine.render_markdown(canonical=args.canonical))
    elif args.json:
        import json
        print(json.dumps(engine.get_metrics(canonical=args.canonical), indent=2))
    else:
        print(engine.render_hud_ansi(canonical=args.canonical))

if __name__ == "__main__":
    main()
