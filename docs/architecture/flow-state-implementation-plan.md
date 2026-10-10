# Plano de Implementação de Engenharia de Fluxo (TUI / Ergonomia / Flow State)

> **Documento de Engenharia & Roadmap Operacional**  
> **Status:** Ativo / Pronto para Execução  
> **Data:** Outubro de 2026  
> **Referência Canônica da Auditoria:** [`workflow-flow-state-audit.md`](workflow-flow-state-audit.md)  
> **Manifesto Base:** [`terminal-ergonomics-and-ux-manifesto.md`](terminal-ergonomics-and-ux-manifesto.md)  
> **Alinhamento de Diretrizes:** Regra Zero-Churn (preservar 100% da memória muscular ativa, adições puras e remoção de atritos residuais).

---

## 0. Contexto, Princípios e Diretrizes de Execução

Este documento traduz os achados empíricos, os defeitos verificados no sistema ao vivo (**F1** a **F10**) e as recomendações científicas consolidadas na auditoria de estado de flow em um **plano de engenharia passo a passo**.

### 0.1 Princípios Norteadores de Implementação

1. **Regra Zero-Churn Biomecânica:** Nenhum atalho ou fluxo motor consolidado (`j + Enter`, `Ctrl+G`, `<Tab>` no shell, modalidade do Vim) pode ser quebrado, remapeado ou sofrer regressão de latência. Modificações na camada de entrada são restritas a correções de desvio de configuração e eliminação de atalhos hostis residuais (ex.: acordes de 4 modificadores).
2. **A Lei de Amdahl para o Flow com IA:** O ganho ergonômico em microssegundos no teclado não resolve o verdadeiro gargalo cognitivo apontado pela literatura de 2025–2026 (METR, DORA, Anthropic): o **tempo de compreensão, validação e revisão de diffs gerados por múltiplos agentes**. O roadmap prioriza aprimoramentos no loop de revisão (`lazygitrs`), telemetria visual e política anti-interrupção.
3. **Determinismo e Tolerância a Falhas:** Popups, daemons e scripts de integração devem possuir resolução determinística de binários, proteções contra saídas silenciosas e diagnósticos automatizados (`doctor`) para impedir desvios silenciosos de configuração.
4. **Governança de Documentação Viva:** Toda alteração de comportamento, timeout, porta ou atalho deve ser sincronizada na documentação e no catálogo do `intelli-shell` no mesmo commit, validada por [`scripts/docs-lint.sh`](../../scripts/docs-lint.sh).

---

## 1. Matriz Executiva de Priorização e Cronograma

| Fase | ID | Tarefa | Alvo / Escopo | Complexidade | Impacto no Flow | Risco / Zero-Churn |
| :---: | :---: | :--- | :--- | :---: | :---: | :---: |
| **P0** | **P0.1** | [Correção do Launcher do Lazygitrs](#p01-resolução-de-binário-e-proteção-anti-crash-do-lazygitrs-popup) (F1) | `tmux/.config/tmux/lazygitrs-popup.sh` | 15 min | **Crítico** (Restaura popup) | Zero risco |
| **P0** | **P0.2** | [Reconciliação do Kernel keyd](#p02-reconciliação-do-kerneldaemon-keyd-overload_tap_timeout--200) (F2) | `/etc/keyd/default.conf` | 5 min | Alto (Elimina engasgos de digitação) | Zero risco |
| **P0** | **P0.3** | [Expansão do Scrollback do Tmux](#p03-expansão-do-buffer-de-scrollback-do-tmux-history-limit-50000) (F4) | `tmux/.config/tmux/tmux.conf` | 5 min | Alto (Preserva logs longos de agentes) | Zero risco |
| **P0** | **P0.4** | [Reconciliação Canônica de Debounce](#p04-reconciliação-canônica-do-debounce-de-agentes-650-ms) (F3) | `docs/` e `acpd/` configs | 15 min | Médio (Alinha documentação e realidade) | Zero risco |
| **P0** | **P0.5** | [Aplicação da Errata nos Documentos](#p05-aplicação-da-errata-nos-documentos-canônicos) (§12) | `docs/architecture/` | 30 min | Médio (Integridade científica) | Zero risco |
| **P1** | **P1.1** | [Guardião de Integridade (`flow-doctor`)](#p11-guardião-de-integridade-automatizado-flow-doctor) (F1, F2, F4) | `scripts/flow-doctor.sh` | 2 h | **Crítico** (Prevenção contínua de drifts) | Zero risco |
| **P1** | **P1.2** | [CLI e Health-Check do ACPD](#p12-acpd-cli-com-suporte-a-flags-padrão-clap-e-rpc-agentstatewait) (F10) | `acpd` daemon (Rust) | 1-2 dias | Alto (Estabilidade de processo) | Baixo |
| **P1** | **P1.3** | [Telemetria Pessoal Zero-Fork](#p13-telemetria-pessoal-zero-fork-bash-5-builtins) | Tmux hooks + `flow-log.sh` | 2 h | Alto (Métricas reais de interrupção) | Zero risco |
| **P1** | **P1.4** | [Sino por Breakpoint e Modo Foco/Triagem](#p14-sino-com-consciência-de-breakpoint-e-alternância-focotriagem) | `acpd` + Tmux activity | 1 dia | **Crítico** (Proteção do estado de flow) | Baixo |
| **P1** | **P1.5** | [Diferenciação Cromática no ACPD](#p15-diferenciação-cromática-estrita-e-fallback-semiótico-seguro) | `acpd` templates + configs | 2 h | Alto (Redução de carga foveal) | Zero risco |
| **P1** | **P1.6** | [Alavancas de Revisão 1 a 3 no Lazygitrs](#p16-aceleração-do-loop-de-revisão-no-lazygitrs-alavancas-de-amdahl-1-a-3) | `lazygitrs` (Rust) | 2-3 dias | **Máximo** (Reduz tempo de supervisão) | Médio |
| **P1** | **P1.7** | [Otimização de Headless Filter & Cache](#p17-otimização-de-filtragem-headless-e-caching-assíncrono-do-popup) (F5, F6) | `waymaker` / scripts | 1 dia | Médio (Garante Doherty < 100ms) | Baixo |
| **P2** | **P2.1** | [Retomada de Agentes Pós-Reboot](#p21-sobrevivência-pós-reboot-e-retomada-de-agentes-agent-resume) | `acpd` / Tmux state | 3-4 dias | Alto (Resiliência operacional) | Médio |
| **P2** | **P2.2** | [Isolamento em Sandbox no `awt`](#p22-isolamento-em-sandbox-para-execução-autônoma-de-agentes-awt) | `awt` runtime | 3 dias | Alto (Segurança contra agentes) | Médio |
| **P2** | **P2.3** | [Portão de Segurança `pre_merge` no AWT](#p23-portão-de-segurança-pre_merge-no-awt-ship) | `awt/` scripts | 1 dia | Médio (Qualidade de trunk) | Zero risco |
| **P2** | **P2.4** | [Higienização de Acordes Hostis](#p24-higienização-de-acordes-hostis-e-resíduos-de-teclado-f7) (F7) | Ghostty / Hypr configs | 1 h | Médio (Ergonomia postural) | Zero risco |
| **P2** | **P2.5** | [Governança de Upstream e Licenças](#p25-governança-de-upstream-e-licenciamento-aberto-f8) (F8) | Repositórios git | 2 dias | Médio (Sustentabilidade de código) | Zero risco |
| **P2** | **P2.6** | [Avaliação Empírica do `fm.rs`](#p26-avaliação-empírica-de-retenção-do-fmrs) | Telemetria do `waymaker` | 4 semanas | Médio (Decisão de manutenibilidade) | Baixo |
| **P3** | **P3.1** | [Frota Multi-Host Distribuída](#p31-supervisão-distribuída-multi-host-via-tailscale) | Tailscale + ACPD mesh | 1-2 meses | Longo prazo (Agentes remotos) | Médio |
| **P3** | **P3.2** | [Diffs Semânticos / Tree-Sitter](#p32-diffs-semânticos-e-estruturais-tree-sitter--difftastic) | `lazygitrs` | 1-2 meses | Longo prazo (Compreensão de código) | Médio |
| **P3** | **P3.3** | [Harness Formal de Benchmark Aberto](#p33-metodologia-e-publicação-de-benchmarks-tui-reprodutíveis) | Suíte de testes | 2-3 semanas | Longo prazo (Reprodutibilidade pública) | Zero risco |

---

## 2. Fase P0 — Correções Críticas e Estabilidade Imediata (Minutos)

### P0.1: Resolução de Binário e Proteção Anti-Crash do Lazygitrs Popup

- **Defeito Identificado (F1):** O launcher [`tmux/.config/tmux/lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh) possui a linha rígida `LZG_BIN="$HOME/.cargo/bin/lazygitrs"`. Na máquina ao vivo, esse caminho continha um binário v0.0.20 legado que não suporta o parâmetro `--commits` nem `-c popup`. Sob `tmux display-popup -E`, erros silenciosos de sintaxe fecham a janela imediatamente sem exibir stderr, provocando falha instantânea no atalho `Ctrl+G`. O binário atualizado (v0.0.38) reside em `~/.local/bin/lazygitrs`.
- **Arquivos Afetados:** [`tmux/.config/tmux/lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh)
- **Solução Técnica:** Implementar resolução determinística de capabilities (`resolve_lzg`), inspecionando suporte a `--commits` nos caminhos candidatos. Adicionar verificação com fallback explícito em caso de ausência do binário.

#### Diff de Implementação

```bash
--- a/tmux/.config/tmux/lazygitrs-popup.sh
+++ b/tmux/.config/tmux/lazygitrs-popup.sh
@@ -36,8 +36,25 @@ unset _tmux_style
-LZG_BIN="$HOME/.cargo/bin/lazygitrs"
-[ -x "$LZG_BIN" ] || LZG_BIN="$(command -v lazygitrs 2>/dev/null || echo "lazygitrs")"
+resolve_lzg() {
+    local candidate
+    for candidate in "$HOME/.local/bin/lazygitrs" "$(command -v lazygitrs 2>/dev/null)" "$HOME/.cargo/bin/lazygitrs"; do
+        [ -x "$candidate" ] || continue
+        # Verifica se o binário suporta a flag moderna --commits
+        if "$candidate" --help 2>&1 | grep -q -- '--commits'; then
+            printf '%s\n' "$candidate"
+            return 0
+        fi
+    done
+    # Fallback para o primeiro executável encontrado
+    for candidate in "$HOME/.local/bin/lazygitrs" "$(command -v lazygitrs 2>/dev/null)" "$HOME/.cargo/bin/lazygitrs"; do
+        [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
+    done
+    return 1
+}
+
+LZG_BIN="$(resolve_lzg)"
+if [ -z "$LZG_BIN" ]; then
+    tmux display-message "Erro: lazygitrs compativel nao encontrado no PATH"
+    exit 1
+fi
```

- **Ação Imediata Adicional:** Remover o binário obsoleto do cargo (`rm -f ~/.cargo/bin/lazygitrs`) para evitar colisões no shell.
- **Validação:**
  ```bash
  ~/.dotfiles/main/tmux/.config/tmux/lazygitrs-popup.sh
  ```
  O popup deve abrir imediatamente com a interface v0.0.38 do Lazygitrs no centro da tela.
- **Rollback:** Restaurar a atribuição anterior da variável `LZG_BIN`.

---

### P0.2: Reconciliação do Kernel/Daemon keyd (`overload_tap_timeout = 200`)

- **Defeito Identificado (F2):** O script instalador [`keyd.zsh`](../../.shell/install/packages/keyd.zsh) e os manifestos documentam o parâmetro `overload_tap_timeout = 200` na seção `[global]`. No entanto, o arquivo ativo do sistema `/etc/keyd/default.conf` continha apenas `[ids]` e `[main]`, sem o timeout configurado. Sem esse parâmetro, digitações ultrarrápidas de `Escape` (tap na tecla CapsLock) podem ser interpretadas incorretamente como `Control` dependendo da pressão, provocando pequenas hesitações cognitivas.
- **Arquivos Afetados:** `/etc/keyd/default.conf`
- **Solução Técnica:** Sobrescrever a configuração do sistema `/etc/keyd/default.conf` com a configuração completa e recarregar o daemon keyd.

#### Comandos de Execução

```bash
sudo tee /etc/keyd/default.conf > /dev/null << 'EOF'
[global]
overload_tap_timeout = 200

[ids]
*

[main]
capslock = overload(control, esc)
EOF

sudo keyd reload
```

- **Validação:**
  ```bash
  grep "overload_tap_timeout" /etc/keyd/default.conf
  sudo systemctl status keyd --no-pager
  ```
  A saída deve exibir `overload_tap_timeout = 200` e o daemon keyd ativo sem erros no journal.
- **Rollback:** `sudo sed -i '/overload_tap_timeout/d' /etc/keyd/default.conf && sudo keyd reload`

---

### P0.3: Expansão do Buffer de Scrollback do Tmux (`history-limit 50000`)

- **Defeito Identificado (F4):** O arquivo [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf) estabelece `set-option -g history-limit 10000`. Em pipelines modernos com múltiplos agentes autônomos streamando compilações, testes unitários e diffs, 10.000 linhas são consumidas em poucos minutos. O impacto de memória para 50.000 linhas por painel é de apenas ~20–40 MB para o servidor tmux, prevenindo perda de contexto visual em investigações pós-execução.
- **Arquivos Afetados:** [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf)

#### Diff de Implementação

```bash
--- a/tmux/.config/tmux/tmux.conf
+++ b/tmux/.config/tmux/tmux.conf
@@ -141,1 +141,1 @@
-set-option -g history-limit 10000
+set-option -g history-limit 50000
```

- **Comandos de Execução:**
  ```bash
  tmux set-option -g history-limit 50000
  ```
- **Validação:**
  ```bash
  tmux show -gv history-limit
  ```
  Deve retornar `50000`.
- **Rollback:** Reverter para `10000`.

---

### P0.4: Reconciliação Canônica do Debounce de Agentes (650 ms)

- **Defeito Identificado (F3):** Divergência documental entre [`popup-isolation-and-debounce.md`](../tmux/popup-isolation-and-debounce.md) (que citava 400 ms), [`tui-ux-workflow-evaluation-report.md`](tui-ux-workflow-evaluation-report.md) (que citava 300 ms) e a configuração ativa [`acpd/.config/acpd/config.toml`](../../acpd/.config/acpd/config.toml) (onde `idle_debounce_ms = 650`). O valor de 650 ms é o ideal biomecanicamente para acomodar pausas naturais entre rajadas de digitação sem disparar notificações falsas.
- **Arquivos Afetados:**
  - [`docs/tmux/popup-isolation-and-debounce.md`](../tmux/popup-isolation-and-debounce.md)
  - [`docs/README.md`](../README.md)
- **Solução Técnica:** Atualizar a documentação para cravar 650 ms como a especificação canônica calibrada e explicar a fundamentação empírica.
- **Validação:** Executar `./scripts/docs-lint.sh`.

---

### P0.5: Aplicação da Errata nos Documentos Canônicos

- **Defeito Identificado (§12 da Auditoria):** Correção de atribuições errôneas na literatura científica (ex.: atribuir superlinearidade abaixo de 100ms a Doherty & Thadhani em vez da faixa de 400ms; conferência de Barke et al. sendo OOPSLA e não CHI; venues e percentuais de Parnin & DeLine).
- **Arquivos Afetados:**
  - [`docs/architecture/terminal-ergonomics-and-ux-manifesto.md`](terminal-ergonomics-and-ux-manifesto.md)
  - [`docs/architecture/tui-ux-workflow-evaluation-report.md`](tui-ux-workflow-evaluation-report.md)
- **Ação:** Aplicar as correções tabuladas na seção 12 de `workflow-flow-state-audit.md` mantendo a integridade de links internos.
- **Validação:** Executar `./scripts/docs-lint.sh`.

---

## 3. Fase P1 — Otimizações Arquiteturais e Guardiões de Fluxo (Dias)

### P1.1: Guardião de Integridade Automatizado (`flow-doctor`)

- **Objetivo:** Evitar regressões silenciosas futuras (como F1, F2 e F4) através de um script de diagnóstico rápido que valida a saúde da infraestrutura do desenvolvedor e retorna código de saída diferente de zero em caso de drift.
- **Arquivos Criados/Afetados:**
  - `scripts/flow-doctor.sh` (novo)
  - `intelli-shell/.config/intelli-shell/custom.commands` (registro no palette de comandos)

#### Código de Implementação: `scripts/flow-doctor.sh`

```bash
#!/usr/bin/env bash
# ==============================================================================
# scripts/flow-doctor.sh
# Diagnosticador de integridade biomecânica e consistência do ambiente de fluxo.
# Retorna exit code 1 se houver qualquer desvio de configuração ativo.
# ==============================================================================
set -euo pipefail

RC=0
warn() { printf '\033[1;31m✖ WARN\033[0m  %s\n' "$*"; RC=1; }
ok()   { printf '\033[1;32m✔ OK\033[0m    %s\n' "$*"; }

echo "=== [Flow Doctor] Verificando integridade do Cockpit TUI ==="

# 1. Consistência de binários e ausência de versões obsoletas no PATH
for bin in lazygitrs wm acpd; do
    declare -A seen=()
    versions_count=0
    for p in "$HOME/.local/bin/$bin" "$HOME/.cargo/bin/$bin" "$(command -v "$bin" 2>/dev/null || true)"; do
        [ -n "$p" ] && [ -x "$p" ] || continue
        ver=$("$p" --version 2>&1 | head -n1 || echo "unknown")
        if [ -z "${seen[$ver]:-}" ]; then
            seen[$ver]="$p"
            versions_count=$((versions_count + 1))
        fi
    done
    if (( versions_count > 1 )); then
        warn "$bin possui $versions_count versões conflitantes no disco: $(printf '%s ' "${!seen[@]}")"
    elif (( versions_count == 1 )); then
        ok "$bin: versão consistente (${!seen[*]})"
    else
        warn "$bin não foi encontrado nos caminhos padrão"
    fi
    unset seen
done

# 2. Configuração do kernel keyd (overload_tap_timeout = 200)
if [ -f /etc/keyd/default.conf ]; then
    if grep -q 'overload_tap_timeout = 200' /etc/keyd/default.conf; then
        ok "keyd: overload_tap_timeout = 200 presente no /etc/keyd/default.conf"
    else
        warn "keyd: /etc/keyd/default.conf não possui 'overload_tap_timeout = 200'"
    fi
else
    warn "keyd: /etc/keyd/default.conf não encontrado"
fi

# 3. Buffer de scrollback do Tmux (>= 30000 linhas)
if command -v tmux >/dev/null 2>&1; then
    hl=$(tmux show -gv history-limit 2>/dev/null || echo 0)
    if (( hl >= 30000 )); then
        ok "tmux: history-limit configurado em $hl linhas"
    else
        warn "tmux: history-limit está em $hl linhas (recomendado >= 30000)"
    fi
fi

# 4. Debounce do daemon ACPD
if [ -f "$HOME/.config/acpd/config.toml" ]; then
    debounce=$(grep -E '^\s*idle_debounce_ms\s*=' "$HOME/.config/acpd/config.toml" | awk -F'=' '{print $2}' | tr -d ' ')
    if [ "$debounce" = "650" ]; then
        ok "acpd: idle_debounce_ms calibrado em 650 ms"
    else
        warn "acpd: idle_debounce_ms está em ${debounce} ms (especificação canônica é 650 ms)"
    fi
fi

# 5. Conectividade do daemon ACPD RPC (se ativo)
if pgrep -x acpd >/dev/null 2>&1; then
    token_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/acpd/token"
    if [ -f "$token_file" ]; then
        token=$(cat "$token_file")
        status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:4040/rpc \
            -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"agentState/list","params":{},"id":1}' || echo "000")
        if [ "$status_code" = "200" ]; then
            ok "acpd: daemon online e respondendo a RPCs autenticados (HTTP 200)"
        else
            warn "acpd: daemon em execução mas endpoint RPC retornou HTTP $status_code"
        fi
    fi
fi

echo "============================================================"
exit $RC
```

- **Critério de Aceite:** Execução de `./scripts/flow-doctor.sh` retorna status 0 com todos os itens exibindo `✔ OK`.

---

### P1.2: ACPD CLI com Suporte a Flags Padrão (`clap`) e RPC `agentState/wait`

- **Defeito Identificado (F10):** No repositório [`~/dev/github/acpd`](file:///home/fecavmi/dev/github/acpd), o binário inicia o runtime de rede imediatamente sem parsing de argumentos de linha de comando. Invocar `acpd --version` ou `acpd --help` tenta instanciar um segundo daemon, travando no arquivo de PID ou gerando log desnecessário.
- **Arquivos Afetados:** `~/dev/github/acpd/Cargo.toml`, `~/dev/github/acpd/src/main.rs`, `~/dev/github/acpd/src/api/`
- **Plano de Implementação:**
  1. Adicionar dependência `clap = { version = "4", features = ["derive"] }` ao `Cargo.toml`.
  2. Implementar estrutura CLI com opções `--version`, `--help`, `--config <PATH>` e subcomando `mode <focus|triage>`.
  3. Adicionar método JSON-RPC `agentState/wait` permitindo que popups e scripts aguardem de forma assíncrona por transições de estado de um agente sem polling ativo.
  4. Implementar reidratação de estado: na inicialização, ler variáveis `@ai_agent_state_*` dos painéis do tmux e repovoar a tabela em memória.

#### Snippet de Refatoração no `src/main.rs`

```rust
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "acpd", author, version, about = "Autonomous Cockpit Protocol Daemon", long_about = None)]
struct Cli {
    /// Caminho customizado para o arquivo de configuração config.toml
    #[arg(short, long, value_name = "FILE")]
    config: Option<String>,

    /// Subcomando de controle imediato do daemon ativo
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(clap::Subcommand, Debug)]
enum Commands {
    /// Alterna o modo de atenção do cockpit (focus ou triage)
    Mode { target: String },
    /// Executa verificação de saúde e conectividade com o daemon
    Health,
}
```

- **Critério de Aceite:** `acpd --version` imprime a versão e encerra com código 0 em < 5 ms, sem tocar no socket ou disparar o tracing logger.

---

### P1.3: Telemetria Pessoal Zero-Fork (Bash 5 Builtins)

- **Objetivo:** Fornecer dados empíricos para validar a hipótese de fluxo de Csikszentmihalyi e interrupções (Mark et al. 2008). Gravar trocas de contexto e chamadas de ferramentas sem onerar o sistema operacional com forks de processos desnecessários.
- **Implementação:**
  - Script `flow-log.sh` utilizando o recurso embutido `printf '%(%s)T'` do Bash 5 (zero forks de binários externos como `date`).
  - Integração via hooks do tmux: `set-hook -g client-session-changed "run-shell 'flow-log.sh session-switch'"` e `set-hook -g pane-focus-in "run-shell 'flow-log.sh pane-focus'"`

#### Código: `utils/.local/bin/flow-log`

```bash
#!/usr/bin/env bash
# ==============================================================================
# utils/.local/bin/flow-log
# Gravador de eventos de telemetria de fluxo pessoal de altíssima velocidade.
# Executa em < 1ms através do builtin printf do Bash 5.
# ==============================================================================
set -euo pipefail

EVENT_TYPE="${1:-unknown}"
DETAIL="${2:-}"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/flow"

[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

# Builtin printf com timestamp de época -1 (momento atual): zero forks
printf '%(%s)T\t%s\t%s\n' -1 "$EVENT_TYPE" "$DETAIL" >> "$LOG_DIR/events.tsv"
```

- **Critério de Aceite:** Execução de 1000 chamadas em loop consome menos de 80 ms totais em benchmark sintético local.

---

### P1.4: Sino com Consciência de Breakpoint e Alternância Foco/Triagem

- **Fundamentação Científica:** Iqbal & Bailey (CHI 2008) demonstraram que notificações entregues em momentos arbitrários aumentam a frustração e o tempo de retomada de tarefas. Notificações retidas até um **breakpoint de tarefa** (uma pausa natural de digitação) preservam o estado de concentração profunda.
- **Arquivos Afetados:**
  - `acpd/.config/acpd/config.toml`
  - `acpd/src/daemon.rs` (ou script wrapper do sound player)
- **Implementação Técnica:**
  - **Dois Modos de Atenção:**
    - **Modo Foco (Maker):** Notificações sonoras restritas a `permission` e `error`. Sons deferidos até que o operador faça uma pausa na digitação de pelo menos 2 segundos (`client_activity` no Tmux >= 2s). Badges visuais continuam atualizando silenciosamente.
    - **Modo Triagem (Supervisor):** Alertas imediatos para qualquer mudança de estado.
  - **Limite Suave de WIP (Work-in-Progress):** Alerta sutil quando mais de 4 agentes estiverem simultaneamente em execução para evitar estouro da capacidade de memória de trabalho (Cowan 2001).

#### Script de Entrega Diferida: `acpd/.local/bin/chime-at-breakpoint`

```bash
#!/usr/bin/env bash
# ==============================================================================
# Entrega de áudio com consciência de breakpoint cognitivo do operador
# ==============================================================================
SOUND_FILE="$1"
IDLE_NEEDED="${IDLE_NEEDED:-2}" # 2 segundos sem digitação
MAX_WAIT="${MAX_WAIT:-20}"       # Limite máximo de espera antes de soar
WAITED=0

while (( WAITED < MAX_WAIT )); do
    CLIENT_ACT=$(tmux display-message -p '#{client_activity}' 2>/dev/null || true)
    [ -z "$CLIENT_ACT" ] && break
    
    printf -v NOW '%(%s)T' -1
    if (( NOW - CLIENT_ACT >= IDLE_NEEDED )); then
        break
    fi
    sleep 0.5
    WAITED=$(( WAITED + 1 ))
done

exec pw-play "$SOUND_FILE"
```

---

### P1.5: Diferenciação Cromática Estrita e Fallback Semiótico Seguro

- **Problema:** Na configuração atual do ACPD, tanto o estado `permission` (urgência interativa: agente bloqueado aguardando autorização) quanto o estado `error` (diagnóstico posterior) compartilham exatamente a mesma cor vermelha (`#e67e80` / `{{ color1 }}`). Na visão periférica, o operador não consegue distinguir um bloqueio de um erro sem ler o glifo com visão foveal.
- **Arquivos Afetados:**
  - [`acpd/.config/omarchy/themed/acpd.toml.tpl`](../../acpd/.config/omarchy/themed/acpd.toml.tpl)
  - [`acpd/.config/acpd/config.toml`](../../acpd/.config/acpd/config.toml)

#### Alteração no Template de Tema

```toml
[theme.states.permission]
icon = "󱅭"
color = "{{ color9 }}"  # Laranja/Âmbar brilhante para atenção interativa

[theme.states.error]
icon = "󰨄"
color = "{{ color1 }}"  # Vermelho estrito para erro/falha
```

- **Fallback ASCII:** Adicionar mapeamento na configuração do ACPD para ambientes remotos (SSH sem fontes patched):
  - `working` -> `[*]`
  - `permission` -> `[?]`
  - `question` -> `[Q]`
  - `idle` -> `[-]`
  - `error` -> `[!]`

---

### P1.6: Aceleração do Loop de Revisão no Lazygitrs (Alavancas de Amdahl 1 a 3)

- **Fundamentação:** A maior fatia do tempo de um desenvolvedor trabalhando com múltiplos agentes é gasta na revisão de diffs. Pequenas melhorias aqui produzem ganhos de produtividade muito maiores do que atalhos de shell.
- **Alavancas a Implementar no Fork `lazygitrs`:**
  1. **Status dos Testes no Cabeçalho do Commit:** Exibir badge com o resultado da última suíte de testes (`✔ 41/41` ou `✘ 2 fail`) associada ao commit do agente.
  2. **Ordenação por Risco de Diff:** Ordenar arquivos modificados priorizando código crítico (arquivos de sistema, schemas, contratos de API) antes de testes e documentação.
  3. **Comentários de Contexto do Agente:** Carregar automaticamente as anotações do agente geradas pelo `awt` em um painel lateral acionável por atalho modal (`Tab`).

---

### P1.7: Otimização de Filtragem Headless e Caching Assíncrono do Popup

- **Defeitos F5 e F6:** O `wm -f` em modo headless gasta 155 ms em 100k linhas (comparado a 43 ms do `fzf`), ultrapassando a barreira de 100 ms em pipelines de automação pesados. Além disso, a chamada síncrona `git status --porcelain` no [`lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh) pode demorar até 180 ms em cold cache.
- **Soluções:**
  1. **Roteamento Híbrido:** Usar `fzf --filter` para filtros headless em listas maiores que 5.000 itens; manter `waymaker` para a interface TUI interativa.
  2. **Verificação Rápida de Git:** Substituir `git status --porcelain` por checagem leve baseada em `git diff --quiet --cached` e `git diff --quiet` (que encerram no primeiro arquivo alterado encontrado), reduzindo o tempo para < 5 ms.

---

## 4. Fase P2 — Resiliência, Sandboxing e Governança (Semanas)

### P2.1: Sobrevivência Pós-Reboot e Retomada de Agentes (Agent Resume)

- **Objetivo:** Emparelhar a capacidade de resiliência com o concorrente Herdr. Se a máquina reiniciar ou a sessão do tmux sofrer crash, os agentes e sessões devem ser restauráveis.
- **Arquitetura:** O ACPD persistirá periodicamente um snapshot em `$XDG_STATE_HOME/acpd/sessions.json` mapeando:
  - `session_id`, `worktree_path`, `tmux_window_name`, `agent_type`, `pid`.
- No boot, um script de restauração reabre as janelas do tmux e reconecta a telemetria aos agentes ativos.

---

### P2.2: Isolamento em Sandbox para Execução Autônoma de Agentes (`awt`)

- **Objetivo:** Proteger o host contra comandos destrutivos acidentais executados por agentes autônomos.
- **Solução:** Integrar suporte opcional a Bubblewrap (`bwrap`) ou rootless containers no `awt provision`. O agente enxerga apenas o diretório do worktree clonado e as ferramentas de compilação essenciais, com `/home` em modo read-only.

---

### P2.3: Portão de Segurança `pre_merge` no `awt ship`

- **Objetivo:** Impedir que código quebrado gerado por agentes seja incorporado à branch principal.
- **Implementação:** O comando `awt ship` executará automaticamente o script de verificação do repositório (`just check`, `cargo test` ou `npm test`) antes de efetuar o merge e a destruição do worktree.

---

### P2.4: Higienização de Acordes Hostis e Resíduos de Teclado (F7)

- **Objetivo:** Alinhar o ambiente ao princípio de ergonomia universal sem quebrar a memória muscular existente.
- **Ações:**
  - Remover do Ghostty o atalho residual de 4 modificadores `super+control+shift+alt+arrow_*`.
  - Remover bind redundante `alt+shift+enter`.
  - Limpar fallbacks legados de Alt no Hyprland após período de verificação de não utilização.

---

### P2.5: Governança de Upstream e Licenciamento Aberto (F8)

- **Ações:**
  - Rebase do fork de `lazygitrs` contra o repositório principal, submetendo PRs das melhorias (`--commits`, dual-diff modal).
  - Incluir arquivos de licença explícitos (MIT / Apache-2.0) em `waymaker` e `acpd`.

---

### P2.6: Avaliação Empírica de Retenção do `fm.rs`

- **Ação:** Coletar telemetria durante 4 semanas através de `flow-log.sh` para verificar a frequência de uso do gerenciador de arquivos embutido `fm.rs` do Waymaker versus o `yazi`.
- Se o uso do `fm.rs` for residual (< 5% das ações de arquivo), congelar a expansão de novos recursos no `fm.rs` para reduzir o débito técnico de manutenção do Rust.

---

## 5. Fase P3 — Pesquisa & Próxima Geração (Longo Prazo)

1. **P3.1: Supervisão Distribuída Multi-Host via Tailscale:** Permitir que o attention ring e a barra de status do tmux agreguem o estado de agentes rodando em servidores remotos através de RPCs seguros via rede Mesh.
2. **P3.2: Diffs Semânticos e Estruturais:** Integração de `difftastic` (Tree-sitter) dentro do visualizador do `lazygitrs`, permitindo ignorar reformatações sintáticas e focar exclusivamente em mudanças lógicas.
3. **P3.3: Metodologia e Publicação de Benchmarks TUI Reprodutíveis:** Criação de um harness público baseado em `vhs` e contadores de ciclos de CPU para benchmarking auditável de ferramentas de terminal.

---

## 6. Procedimentos de Teste, Validação e Checklist Geral

### Checklist Pré-Execução

- [ ] Verificar se o worktree atual está limpo (`git status --porcelain`).
- [ ] Executar `./scripts/docs-lint.sh` para garantir integridade inicial de links.

### Checklist P0 (Execução Imediata)

- [ ] Aplicar patch em `tmux/.config/tmux/lazygitrs-popup.sh` e remover `~/.cargo/bin/lazygitrs`.
- [ ] Aplicar `overload_tap_timeout = 200` em `/etc/keyd/default.conf` e executar `sudo keyd reload`.
- [ ] Atualizar `tmux/.config/tmux/tmux.conf` com `history-limit 50000` e aplicar via `tmux source`.
- [ ] Atualizar referências de debounce para 650 ms canônico.
- [ ] Aplicar errata de referências bibliográficas.
- [ ] Validar com `./scripts/docs-lint.sh`.

### Checklist P1 (Curto Prazo)

- [ ] Criar e testar `scripts/flow-doctor.sh`.
- [x] Implementar `flow-log.sh` e hooks de telemetria no Tmux (medição de latência humano/revisão e `flow-telemetry`).
- [ ] Ajustar cores de `permission` vs `error` no template do ACPD.
- [ ] Adicionar suporte a `clap` em `acpd` e testar `acpd --version`.

---

## 7. Rastreabilidade e Documentos Relacionados

- **Auditoria Científica Completa:** [`workflow-flow-state-audit.md`](workflow-flow-state-audit.md)
- **Manifesto de Ergonomia de Terminal:** [`terminal-ergonomics-and-ux-manifesto.md`](terminal-ergonomics-and-ux-manifesto.md)
- **Matriz de Teclas de Atalho:** [`workflow-keybindings-matrix.md`](workflow-keybindings-matrix.md)
- **Validador de Integridade Documental:** [`scripts/docs-lint.sh`](../../scripts/docs-lint.sh)
