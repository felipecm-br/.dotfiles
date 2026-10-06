# Auditoria do Workflow para Estado de Flow — Ergonomia, Zero Fricção e UX de TUI

> **Versão em português** de [`../architecture/workflow-flow-state-audit.md`](../architecture/workflow-flow-state-audit.md) (documento canônico, em inglês). Em caso de divergência, vale o canônico.
> **Escopo:** `keyd` → Ghostty → tmux → `waymaker` (`wm`) → `lazygitrs` (branch `fecavmi`) → `acpd` → `awt`, comparados com Herdr, workmux, Agent of Empires, Age of Agents, Yazi, superfile e afins.
> **Data:** 2026-10-05 · **Método:** medições locais + READMEs/APIs dos projetos + checagem de literatura (ver [§0](#0-método-graus-de-evidência-e-limites)).
> **Relação com docs existentes:** esta auditoria **substitui as conclusões** (não a estrutura) de [`tui-ux-workflow-evaluation-report.md`](../architecture/tui-ux-workflow-evaluation-report.md) e de [`workflow-vs-herdr-comparison.md`](workflow-vs-herdr-comparison.md). As correções estão na [§12](#12-errata-dos-docs-existentes). A doutrina ergonômica do [manifesto](../architecture/terminal-ergonomics-and-ux-manifesto.md) é mantida (Regra Zero-Churn).

---

## 0. Método, graus de evidência e limites

| Grau | Significado |
| :---: | :--- |
| **A** | Medido ou lido diretamente nesta máquina / no código-fonte do projeto durante a auditoria. |
| **B** | Confirmado por resumo de buscador sobre o paper/site; o PDF primário **não** foi aberto. |
| **C** | Conhecimento de base (de memória), **não** reverificado aqui. Tratar como hipótese. |

**Limites (leia antes de confiar em qualquer número):**
- Todas as medições vêm de **uma máquina** (Arch/Omarchy, Ghostty 1.3.1, tmux 3.7c), melhor-de-N ou média-de-N, sem fixar CPU, sem `hyperfine`. São direcionais, não publicáveis.
- O start-up por `--version` mede `fork+exec+link dinâmico`, **não** o primeiro frame da TUI. A latência do primeiro frame **não** foi medida (ver [§9.3](#93-como-medir-direito)).
- Afirmações sobre concorrentes vêm dos READMEs/sites deles; nada foi instalado ou executado, exceto `yazi`, `fzf`, `zoxide`, `sesh`, que já estavam na máquina.
- As notas da [§1](#1-resumo-executivo) são **julgamento meu** contra um critério explícito, não medição.

---

## 1. Resumo executivo

### 1.1 Veredito

Este é um **cockpit de teclado de primeira linha para um único operador**: a camada de hardware (`keyd`), a navegação sem verbo (`Tab` → `wm -o jump`), a disciplina de popups no eixo Z, a telemetria estruturada de agentes (`acpd`) e o loop de revisão (`lazygitrs` dual-diff + injeção de review notes) são, cada um, excelentes e, combinados, **sem equivalente em nenhum concorrente que verifiquei**.

**Ainda não é o "ápice"**, por cinco razões com evidência:

1. **Três defeitos/desvios verificados no sistema ao vivo** (um deles quebra silenciosamente o popup `Ctrl+G`) — [§2](#2-achados-verificados-sistema-ao-vivo).
2. **O gargalo central está mal mirado.** Ganhos em nível de tecla (130 ms vs 3 s) não mexem na métrica que a literatura 2025–2026 aponta como dominante no trabalho com IA: *tempo de compreensão/verificação por diff* — [§4.3](#43-lei-de-amdahl-para-o-flow-e-a-correção-do-fan-out).
3. **Nada é medido.** As tabelas KLM são estimativas de modelo; não há telemetria pessoal, então nenhuma afirmação é falseável — [§10](#10-modelo-de-engenharia-do-estado-de-flow).
4. **Resiliência e portabilidade são o eixo mais fraco** (estado do `acpd` só em memória, desvio do `/etc/keyd`, só Linux, três forks de mantenedor único com 0 stars externas) — [§7](#7-seção-2--validação-home-row--vim) e [§11](#11-roadmap-priorizado).
5. **A base de evidências citada nos docs tem erros** (Doherty, Parnin & DeLine, Barke et al., Dhakal et al.) e **os fatos sobre concorrentes estão defasados** (o workmux agora tem modo sessão, sidebar e dashboard; o Herdr traz integrações de configuração por agente, não só heurística de tela) — [§12](#12-errata-dos-docs-existentes).

### 1.2 Placar (julgamento; critério na [§1.3](#13-critério))

| Dimensão | Design | Como instalado | Por quê |
| :--- | :---: | :---: | :--- |
| Biomecânica de entrada (keyd, sem Alt) | **9,0** | 8,5 | `capslock = overload(control, esc)` ativo; tmux/nvim têm 0 binds de Alt. Menos: `keyd` ao vivo sem o `overload_tap_timeout` documentado; chord de 4 modificadores no Ghostty; fallbacks de Alt no Hypr. |
| Latência / responsividade | **9,0** | 8,0 | Binários iniciam em 2,7–6 ms (A). Menos: `wm -f` 2,3–4,9× mais lento que `fzf --filter` de 10k a 384k linhas; `git status` síncrono no pré-check do popup. |
| Navegação zero fricção (`j`, `Tab`, `ptl`) | **9,0** | 9,0 | Object-first + frecency; mas o ganho sobre o `zoxide` é ≈0 para alvos *conhecidos* ([§4.2](#42-recomputação-klm-goms-com-baselines-explícitas)). |
| Loop de revisão Git/IA | **9,0** | **4,0** | Dual-diff + injeção de notas é único. **Como instalado, o popup do tmux executa um binário v0.0.20 obsoleto que rejeita `-c`** (F1). |
| Supervisão e telemetria de agentes | **8,5** | 8,0 | Hooks estruturados + sons + attention ring. Menos: sem limite de WIP, sem entrega por breakpoint, estado em memória. |
| Semiótica visual / cognição | **8,0** | 8,0 | Camadas com dupla codificação (glifo + cor) são sólidas; a justificativa "razão áurea/foveal" não é ([§8](#8-seção-3--semiótica-visual-cores-e-eye-tracking)). |
| Resiliência, portabilidade, remoto | **6,0** | 5,5 | A vantagem central do Herdr está aqui. |
| Medição e disciplina de evidência | **4,0** | 4,0 | Números só de modelo; erros de citação. |
| Manutenibilidade / bus factor | **5,0** | 5,0 | `wm` 53k LOC + fork do `lazygitrs` 49k LOC + `acpd`; todos com um único mantenedor ativo no lado do fork. |
| **Geral ponderado** | **8,0** | **6,9** | Pesos: ergonomia 15, latência 15, navegação 10, revisão 20, supervisão 15, semiótica 5, resiliência 10, medição 5, manutenção 5. |

### 1.3 Critério

10 = melhor da categoria **e** evidenciado/medido; 8 = melhor da categoria por design, evidência parcial; 6 = funciona para o dono, frágil fora; 4 = quebrado ou sem evidência. "Como instalado" desconta os defeitos verificados.

### 1.4 Dez ações prioritárias (valor ÷ esforço)

| # | Ação | Esforço | Evidência | Seção |
| :-: | :--- | :---: | :---: | :---: |
| 1 | Corrigir a resolução do `lazygitrs` obsoleto em `lazygitrs-popup.sh` (ou `cargo uninstall`) | 5 min | **A** | [F1](#f1--o-popup-ctrlg-executa-um-binário-obsoleto-que-rejeita-as-próprias-flags) |
| 2 | Reaplicar a config do `keyd` para o `/etc/keyd/default.conf` ao vivo bater com o instalador | 2 min | **A** | [F2](#f2--config-do-keyd-ao-vivo-divergiu-do-instalador-e-dos-docs) |
| 3 | Reconciliar docs do debounce do `acpd` (300/400 ms) com o `650 ms` ao vivo | 10 min | **A** | [F3](#f3--debounce-documentado-de-três-formas-diferentes) |
| 4 | Corrigir erros de citação/concorrentes ([§12](#12-errata-dos-docs-existentes)) | 1 h | **A/B** | §12 |
| 5 | Adicionar telemetria pessoal de ~6 linhas (trocas de contexto, espera→resposta do agente, tempo de revisão) | 1 h | C→mensurável | [§10.3](#103-instrumentação-n-de-1) |
| 6 | **Limite de WIP (3–4 agentes)** suave + chave Focus/Triage no `acpd` | 1 dia | B | [§10.2](#102-dois-modos-de-flow-não-um) |
| 7 | **Reduzir custo de revisão**: fila de arquivos por risco, resultado de testes *antes* do diff, empurrão para lotes pequenos | 2–4 dias | B | [§4.3](#43-lei-de-amdahl-para-o-flow-e-a-correção-do-fan-out) |
| 8 | Entrega de som por breakpoint (adiar o chime até a pausa de digitação) | 2 h protótipo | B | [§11 P1](#p1--dias) |
| 9 | Reidratar estado do `acpd` a partir das opções de pane do tmux + RPC `agentState/wait` | 2 dias | B/C | [§11 P1](#p1--dias) |
| 10 | Investigar a lentidão do filtro headless do `wm` (perfilar scoring: depth penalty, dir-first) | 1 dia | **A** | [F5](#f5--wm--f-é-mais-lento-que-fzf---filter-acima-de-10k-linhas) |

---

## 2. Achados verificados (sistema ao vivo)

Tudo abaixo foi reproduzido nesta máquina em 2026-10-05 (**grau A**), salvo indicação.

### F1 — O popup `Ctrl+G` executa um binário obsoleto que rejeita as próprias flags

- [`lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh) prefere fixo `$HOME/.cargo/bin/lazygitrs` em vez de `command -v lazygitrs`.
- `~/.cargo/bin/lazygitrs` é a **v0.0.20 (2026-05-18)**; `~/.local/bin/lazygitrs` é a **v0.0.38 (2026-10-04)**; o `which -a` lista a v0.0.38 primeiro, então um shell interativo esconde o problema.
- O script executa `lazygitrs -d -c popup [--commits]`. Na v0.0.20, `-d` é `--debug` e `-c` não existe:

```text
$ ~/.cargo/bin/lazygitrs -d -c popup --commits
error: unexpected argument '-c' found
```

- A flag `--commits` e o toggle dual-diff `Ctrl+G` vieram depois (commits `afaa308`/`c3f1caa` na branch `fecavmi`, publicados em `v0.1.0-cockpit`).
- **Impacto:** com `-E` do tmux, uma saída imediata com erro fecha o popup na hora → o gesto principal de revisão aparece como um flash/no-op. **Correção na [§6](#6-seção-5--código-de-implementação-pronto-para-produção) (a).**

### F2 — Config do `keyd` ao vivo divergiu do instalador e dos docs

| Fonte | `overload_tap_timeout` |
| :--- | :--- |
| [`.shell/install/packages/keyd.zsh`](../../.shell/install/packages/keyd.zsh) | `[global] overload_tap_timeout = 200` |
| 3 docs (manifesto §4.1, matriz de keybindings, relatório de avaliação) | "protegido por `overload_tap_timeout = 200`" |
| **`/etc/keyd/default.conf` ao vivo** (datado 2025-12-09) | **ausente** — só `capslock = overload(control, esc)` |

O instalador foi melhorado depois que a máquina foi configurada e nunca reexecutado. Consequência: sem o timeout, um hold longo seguido de release sem outra tecla emite um `Esc` perdido. Dano baixo no Vim, não nulo em TUIs modais onde `Esc` desfaz um diálogo (doutrina do cascading escape).
Além disso, `/etc/keyd` está fora do Stow → a camada de hardware só é reproduzível pelo instalador, e o instalador pode divergir.

### F3 — Debounce documentado de três formas diferentes

| Fonte | Valor |
| :--- | :---: |
| índice `docs/README.md` → *popup-isolation-and-debounce* | **400 ms** |
| `tui-ux-workflow-evaluation-report.md` §5.2 | **300 ms** |
| `~/.config/acpd/config.toml` ao vivo (`idle_debounce_ms`) | **650 ms** |

Violação do princípio de documentação viva (docs e código nunca divergem). O valor importa: 650 ms de debounce ocioso é perceptível frente aos limiares de 100–400 ms ([§3](#3-registro-de-evidências-científicas)).

### F4 — `history-limit 10000` é baixo para agentes em streaming

`tmux show -g history-limit` → `10000`. TUIs de agentes que renderizam na tela principal podem emitir >10k linhas num único turno longo; a extração de scrollback (`Prefix y`, `Prefix E`) passa a perder o início do turno silenciosamente. Subir para 30–50k e medir RSS (a memória escala com células *usadas* por linha, por pane). **Grau A (valor), C (impacto).**

### F5 — `wm -f` é mais lento que `fzf --filter` acima de ~10k linhas

Filtro headless, stdin, consulta `zshfun`, melhor de 5, top-3 idêntico:

| Linhas de entrada | `fzf --filter` | `wm -f` | Razão |
| ---: | ---: | ---: | :---: |
| 10.000 | 11 ms | 25 ms | 2,3× |
| 100.000 | 43 ms | 155 ms | 3,6× |
| 383.807 | 125 ms | 610 ms | 4,9× |

O `wm -f` passa de 100 ms em torno de **60k linhas** (interpolação linear). Prováveis contribuintes (hipóteses, **C**): depth penalty, tiering dir-first, carga de config/preset, abertura do `redb`. Ressalvas: o modo interativo faz streaming incremental (nucleo), então a latência *percebida* é menor que esse número headless; os números de `wm -f ... --no-read` foram descartados (ele ignora o stdin e roda o walker). Importa para widgets ZLE que chamam `wm -f` de forma síncrona em árvores grandes.

### F6 — `git status` síncrono no pré-check do popup

O `lazygitrs-popup.sh` roda `git status --porcelain` antes de abrir o popup para escolher Files vs `--commits`. A quente: **10 ms** (este repo). Primeira chamada após muita mudança no worktree do `waymaker`: média de **182 ms em 3 execuções** (inclui refresh de índice a frio). Equivalentes mais baratos medidos a quente: `git status --porcelain -uno` 7 ms, `git ls-files --others …` 5 ms. Considerar `core.untrackedCache=true` e avaliar `core.fsmonitor`. **Grau A (números), C (ganho em monorepos).**

### F7 — Resíduos de hardware contra a doutrina "sem Alt"

- tmux: **0** binds `M-*` (✓). Neovim: **0** mapas `<A-…>/<M-…>` (✓).
- Hyprland [`bindings.lua`](../../hypr/.config/hypr/bindings.lua): **15** linhas ainda referenciam `ALT` (fallbacks legados documentados).
- Config do Ghostty: `alt+shift+enter=csi:13;4u` (alimenta um bind `M-S-Enter` do tmux que não existe mais no `tmux.conf`) e um chord de **quatro modificadores** `super+control+shift+alt+arrow_*` para `resize_split`. Quatro modificadores simultâneos são o oposto da doutrina.

### F8 — Licenciamento/jurídico a verificar antes de abrir o código

O `waymaker` usa **AGPL-3.0** (`LICENSE` presente) mas é fork do `Squirreljetpack/matchmaker`, cuja detecção de licença no GitHub é `NOASSERTION` (`LICENSE` customizada). O `acpd` não tem arquivo de licença. Verificar os termos do upstream antes de publicar (`OPENSOURCE_PLAN.md`). **Grau A (fatos), C (conclusão jurídica).**

### F9 — Retrato de maturidade/bus factor

| Projeto | LOC Rust | `#[test]` | Commits desde abr/2026 | Autores | Workflows CI | Stars |
| :--- | ---: | ---: | ---: | :--- | :--- | ---: |
| `waymaker` | 53.354 | 317 | 774 | felipe 477 / autor upstream 441 | release, publish | 0 |
| `lazygitrs` (fork) | 49.113 | 168 | 303 | upstream 339 / felipe 82 / outros 10 | release, publish-registries | 0 (upstream 32) |
| `acpd` | 5.385 | **11** | 39 | felipe 39 | release | 0 |

O `acpd` é o hub de telemetria *de carga crítica* com a **menor cobertura de testes** (11 testes / 5,4k LOC, sem diretório `tests/`) e **estado só em memória** (reiniciar perde todos os estados de pane até o próximo hook). O fork do `lazygitrs` está saudável: 81 commits à frente, 3 atrás do upstream.

---

### F10 — `acpd --version` inicia um daemon em vez de imprimir a versão

O `main.rs` lê `std::env::args()` posicionalmente (segundo argumento = caminho da config) e não faz parsing de flags, então `acpd --version`/`--help` sobem uma instância completa do daemon (log `Starting ACP Daemon`). Nesta máquina as instâncias espúrias falharam sem dano no `TcpListener::bind` (porta 4040 ocupada) **antes** de `generate_and_save_token()`, então o token ao vivo (`$XDG_RUNTIME_DIR/acpd/token`, mtime = início do serviço) e o `/tmp/acpd.pid` ficaram intactos (verificado). Com o serviço parado, o mesmo comando subiria silenciosamente um segundo daemon e rotacionaria o token. Qualquer "sonda de versão" em ferramentas (inclusive o [doctor da §6](#6-seção-5--código-de-implementação-pronto-para-produção)) **não** deve chamar `acpd --version`. Correção: adicionar `clap` (`--version`, `--help`, `--config`). **Grau A.**

### Correção de uma medição anterior desta auditoria

O primeiro tempo de RPC do `acpd` (14 ms) usou o caminho de token errado e mediu respostas `401` mais o custo de fork do `curl`. Remedido com o token correto, `curl %{time_total}`, n = 100: `GET /health` **0,74 ms**, `POST /rpc agentState/list` autorizado **0,79 ms** (HTTP 200). RSS do daemon ≈ 6–9 MB (`systemctl --user status`: 8,7 M, pico 10,1 M). O `acpd` não é problema de latência.

---

## 3. Registro de evidências científicas

Afirmações reverificadas. "Afirmação do repo" = o que os docs existentes dizem; "Veredito" é meu.

| Fonte (grau) | O que realmente mostra | Afirmação do repo | Veredito |
| :--- | :--- | :--- | :--- |
| **Miller 1968; Card, Robertson & Mackinlay 1991** (B) | 0,1 s ≈ instantâneo; 1 s ≈ fluxo de pensamento ininterrupto; 10 s ≈ limite de atenção | "Limiar de Doherty (<100 ms)" | **Atribuição errada.** A regra dos 100 ms é de Miller/Card. |
| **Doherty & Thadhani 1982, IBM** (B) | Produtividade sobe *super-linearmente* quando a resposta cai **abaixo de ~400 ms** ("limiar de Doherty = 400 ms") | "<100 ms", "hiper-linear abaixo de 400 ms" em dois lugares | **Parcialmente errado.** Manter o ponto super-linear; corrigir o número. |
| **Dhakal, Feit, Kristensson & Oulasvirta, CHI 2018** (B) | 136M teclas/168k digitadores; **rollover** (teclas sobrepostas) usado em 40–70 % das teclas por digitadores rápidos | "rolls para dentro (`CapsLock+G`, `j+Enter`) são mais rápidos / menos erros" | **Exagerado/mal aplicado.** O paper estabelece rollover como estratégia de digitação rápida; não testa chords com Ctrl nem compara "dentro vs fora". `CapsLock+G` é um *chord mantido*, não um roll. `j`→`Enter` é um roll sequencial genuíno. |
| **METR, jul/2025** (B) | RCT, 16 devs OSS experientes, 246 tarefas: com IA **19 % mais lentos**, acreditavam estar 20 % mais rápidos | Citado corretamente | **Válido mas datado.** O follow-up de fev/2026 foi considerado **não confiável** pelo próprio METR (viés de seleção; devs recusaram o braço sem IA; agentes concorrentes quebram o tempo-na-tarefa). Não existe RCT válido sobre *UX de supervisão de agentes em paralelo*. |
| **Anthropic RCT, jan/2026, "How AI assistance impacts the formation of coding skills"** (B) | 52 engenheiros aprendendo Trio: grupo com IA **−17 pp** no quiz de compreensão; ganho de velocidade não significativo; padrões de "delegação total" foram os piores; padrões de pergunta conceitual preservaram o aprendizado | Não citado | **Altamente relevante.** Apoia designs de "revisão ativa" (escrever review notes) e alerta contra carimbar sem ler. |
| **DORA 2025 State of AI-assisted Software Development** (B) | IA amplifica; mais throughput correlaciona com **mais instabilidade**; lotes maiores fazem a revisão virar gargalo | Não citado | **Altamente relevante** para o design de revisão e empurrões de tamanho de commit. |
| **Gloria Mark et al., CHI 2008** (B) | Interrompidos terminam mais rápido, porém com mais **estresse, frustração, pressão de tempo**; qualidade igual | Não citado | Útil. O número popular "23 min 15 s" vem de uma entrevista, **não** do paper. |
| **Parnin & DeLine, CHI 2010** (B) | Só **~10 %** das sessões de programação retomam em <1 min | "ICSE 2010 … 16 % … 10–15 min" | **Venue e número errados.** |
| **Barke, James & Polikarpova, OOPSLA/PACMPL 2023** (B) | Modos de aceleração vs exploração; 20 programadores; Distinguished Paper | "ACM CHI 2023" | **Venue errado.** A conclusão em si é usada corretamente. |
| **Iqbal & Bailey, CHI 2008** (B) | Adiar notificações para **breakpoints** reduz frustração e acelera a retomada | "redução de disrupção de 30 %–50 %" | **Direção certa, número não verificado.** |
| **Altmann & Trafton 2002** (C) | A ativação de metas na memória decai com a interrupção | Citado | Plausível; venue/ano de memória. |
| **Olsen & Goodrich 2003** (C) | Fan-out `FO = (NT+IT)/IT = 1 + NT/IT` | `FO = 1 + AT/IT`, depois "**19 agentes**" | Fórmula ok; a **extrapolação é inválida** ([§4.3](#43-lei-de-amdahl-para-o-flow-e-a-correção-do-fan-out)). |
| **Keir, Bach, Hudes & Rempel 2007** (B) | Limiares de pressão no túnel do carpo; desvio ulnar ≤ **~14,5°** mantém 75 % das pessoas abaixo de 30 mmHg | Cita "Marklin 2020; Rempel 1998/2008"; "25–35° ulnar em chords com Alt" | **Direção certa; o 25–35° para chords com Alt não tem suporte** — precisa ser medido (goniômetro/vídeo). |
| **Lane, Napier, Peres & Sándor 2005** (B) | A maioria dos usuários nunca migra de menus para atalhos | Implícito | Apoia o HUD in-situ (`Prefix ?`). |
| **Grossman, Dragicevic & Balakrishnan, CHI 2007** (B) | Estratégias para acelerar o aprendizado de hotkeys | "transição para expert 2,5× mais rápida" | **Número não verificado** (não encontrei). |
| **Scarr, Cockburn, Gutwin & Bunt, CHI 2012 (CommandMaps)** (B) | Layouts espacialmente estáveis, tudo-de-uma-vez, superam menus hierárquicos via memória espacial | "superam menus adaptativos em 35 %" | **Direção certa; 35 % não verificado.** Apoia a estabilidade espacial dos popups. |
| **Tognazzini "Ask Tog" (folclore)** (B) | Usuários *percebem* o teclado como mais rápido que o mouse medido; contestado | Não citado | Alerta: velocidade **percebida** ≠ medida — motivo para instrumentar ([§10.3](#103-instrumentação-n-de-1)). |
| **Meyer, Fritz, Murphy & Zimmermann 2014/2019** (B) | Produtividade = agência + progresso ininterrupto; reuniões/interrupções não são uniformemente nocivas | Não citado | Apoia modelo de atenção *controlado pelo usuário* (pull > push). |
| **Cowan 2001 (4±1); Miller 1956 (7±2)** (C) | Capacidade de chunks da memória de trabalho | Ambos usados | Ok; preferir Cowan para chunking de UI. |
| **"Razão áurea melhora o foco foveal"** (—) | Nenhum estudo de suporte encontrado | Central na geometria dos popups | **Justificativa sem suporte.** A geometria (75 %×60 %, centralizada, fundo visível) é boa por *preservação de contexto*; abandonar a justificativa φ/foveal ([§8](#8-seção-3--semiótica-visual-cores-e-eye-tracking)). |
| **"Ícones decodificam em ~15 ms vs 200 ms de texto"** (—) | Nenhum estudo de suporte encontrado | Manifesto §2.1 | **Número sem fonte.** Existem features pré-atentivas (Treisman, C), mas glifos *aprendidos* exigem familiaridade. |

---

## 4. Seção 1 — Diagnóstico ergonômico, biomecânico e KLM-GOMS

### 4.1 Avaliação biomecânica

| Tópico | Avaliação | Grau |
| :--- | :--- | :---: |
| `CapsLock → Ctrl/Esc` na home row | Elimina o alcance ao Ctrl do canto e o desvio ulnar que ele induz. Apoiado em direção por trabalhos de postura do punho (Keir et al. 2007: desvio ulnar ≲ 14,5° mantém a maioria abaixo de 30 mmHg de pressão no túnel do carpo). A *magnitude* do benefício para este usuário é **não medida**. | B |
| Terminologia "inward roll" | `j`→`Enter` é um roll sequencial real (Dhakal 2018: rollover é estratégia de digitação rápida). **`CapsLock+G/S/F` é um chord estático mantido** (mindinho segura, indicador toca), não um roll. A classe de risco é *carga estática no mindinho*, mitigada pela posição na home row, não eliminada. | B |
| Chords de Ctrl com a mesma mão em teclas da esquerda (`C-g`, `C-s`, `C-f`, `C-t`) | Um dedo segura, outro toca; alternância bimanual seria mais suave. Não existe Ctrl do lado direito. Um Ctrl direito espelhado é uma *opção a avaliar com telemetria*, **não** a adotar agora (Regra Zero-Churn; e **não** sobrecarregar `Enter`, isso ameaçaria o roll sagrado `j`+`Enter`). | C |
| `Ctrl+Shift+<tecla da mão esquerda>` (`C-S-g`, `C-S-i`, `C-S-t`) | Chord de três teclas. Usar o Shift **direito** para letras da esquerda evita mindinho(Caps)+mindinho(LShift)+indicador na mesma mão. Também exige CSI-u/`extended-keys` ponta a ponta ([§7.4](#74-eixo-de-resiliência-remoto-e-portabilidade)). | C |
| `Esc` por tap | O `keyd` emite o tap no **release**, então os 120 ms são limitados pelo tempo de contato (típico 80–150 ms), não zero. Aceitável. | A |
| Carga estática / dosimetria | A stack não tem sinal de *dose* (teclas/dia, adesão a micro-pausas). O `hibiki` já vê toda tecla — um contador diário é quase de graça ([§10.3](#103-instrumentação-n-de-1)). | C |

### 4.2 Recomputação KLM-GOMS com baselines explícitas

Valores dos operadores (Card, Moran & Newell; **C**): `K` = 0,12 s (melhor digitador) / **0,20 s** (bom) / 0,28 s (médio), `P` = 1,10 s, `H` = 0,40 s, `M` = 1,35 s, `R` = resposta do sistema. **Regra de colocação:** `M` é removido dentro de uma unidade cognitiva totalmente superaprendida — logo `M ≈ 0` vale *só após a consolidação*; para um usuário novo `M` volta a 0,6–1,35 s por decisão. Os docs existentes usam `M ≈ 0` incondicionalmente e comparam com uma baseline **GUI/mouse** (B0). Uma baseline justa é um usuário competente de terminal puro com aliases (B1).

As tarefas usam `K = 0,20 s`. O `R` do start-up de `wm`/`lazygitrs` é ≈ 3–6 ms (medido, [§9](#9-relatório-de-desempenho)); os demais `R` são suposições.

| Tarefa | B0 GUI/mouse | B1 terminal puro | Esta stack | Ganho vs B1 | Nota |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Abrir revisão da working tree** | 3,2 s (`H`+`P`+clique+`R`≈1,5) | 1,25 s (`lg⏎`: `M`0,35 + 3`K` + `R`0,3) | **0,35 s** (`C-g`: `M`0,1 + `K` + `R`) | **3,6×** | Valor de design; **hoje quebrado pelo F1.** |
| **Ir a um diretório conhecido** (fragmento de 3 letras) | — | `cd` + Tab 3,8 s; **`zoxide` `z foo⏎` 1,8 s** | **1,65 s** (`Tab`+`foo`+`⏎` com confirmação visual `M`0,6) | **1,1× vs zoxide**, 2,3× vs `cd` | O ganho sobre o zoxide é ≈0 para alvos *conhecidos*; a vitória é em alvos **ambíguos/desconhecidos** (previews, fonte tri-modal) e no object-first sem verbo. |
| **Copiar arquivo para o último destino** | — | 4,6 s (`cp f ~/dir/` ≈ 20 teclas) | **2,95 s** (`ptl file.txt⏎`, 13 teclas) / **2,4 s** (picker object-first + `ptl⏎`) | 1,6–1,9× | Os **220 ms documentados omitem a digitação do argumento**; só `ptl file.txt⏎` já custa ≥ 1,56 s com `K` = 0,12. |
| **Dispensar modal** | 0,60 s (`H`+`K`) | 0,60 s | **0,12–0,20 s** (tap `CapsLock`) | 3–5× | Só vale se a mão está na home row. |
| **Ir ao agente que precisa de mim** (6 janelas) | 3,2 s | ≈ 2,2 s (busca visual `M` 1,35 + seleção) | **0,45 s** (`C-S-i`) | 4,9× | Maior ganho de *atenção*: elimina a busca visual. |

Leitura: os ganhos realistas são **1,1×–5×**, não 16–22×. Ainda excelente — e, mais importante, é a *alavanca errada* para o maior custo, como mostra a seguir.

### 4.3 Lei de Amdahl para o flow e a correção do fan-out

Amdahl: `S = 1 / ((1 − p) + p/s)`. Fan-out (Olsen & Goodrich, **C**): `FO = 1 + NT/IT`, `NT` = tempo de negligência (o agente roda sem supervisão), `IT` = tempo de interação por ciclo.

Considere um ciclo de revisão com `IT = 60 s`, dos quais **navegação/troca é p ≈ 5 % (3 s)**. Tornar a navegação *infinitamente* rápida dá `S = 1/0,95 = 1,05`. Com `NT = 180 s`: `FO` vai de 4,00 a 4,16.
O "**19 agentes**" do relatório anterior supôs `IT = 10 s`, isto é, ler e julgar um diff **6× mais rápido**, o que nada na stack entrega e que conflita com:
- METR 2025 (verificação domina), RCT da Anthropic jan/2026 (−17 pp de compreensão sob delegação), DORA 2025 (lotes maiores de IA tornam a revisão o gargalo) — todos grau B;
- Os `4 ± 1` chunks de Cowan (**C**): o *acompanhamento simultâneo de metas* satura perto de 3–4, independentemente da velocidade de troca.

**Conclusão:** os próximos ganhos vêm de reduzir o **custo de compreensão por diff**, não as teclas. Alavancas, por valor esperado:

1. **Lotes pequenos** — commit por tarefa (DORA). Fazer o wizard `awc`/AGENTS.md empurrar para ≤ N linhas alteradas por turno do agente.
2. **Testes como oráculo antes de ler** — mostrar verde/vermelho + nomes de testes falhando no cabeçalho do `lazygitrs` para `HEAD`/working tree, de modo que "funciona?" seja respondido antes da leitura.
3. **Fila de revisão ordenada por risco** — ordenar arquivos por *churn × centralidade × sem teste*; recolher automaticamente lockfiles, snapshots e código gerado.
4. **Diff estrutural/semântico** para moves/renames (avaliar `difftastic` como pager externo; **não verificado aqui**).
5. **Revisão ativa, não aprovação** — manter a injeção de review note `S` (escrever uma nota é padrão de alto engajamento na taxonomia da Anthropic); considerar uma ação "pergunte ao agente *por quê*" (a pergunta conceitual preservou o aprendizado naquele estudo).
6. **Limite de WIP 3–4** e chave Focus/Triage ([§10.2](#102-dois-modos-de-flow-não-um)).
7. **Time-box e registro** de cada revisão com um desfecho posterior (taxa de revert) para calibrar ([§10.3](#103-instrumentação-n-de-1)).

---

## 5. Panorama competitivo

Stars de **2026-10-05** (API do GitHub, **A**). Fatos de funcionalidades vêm do README/site de cada projeto (**A** para "declarado pelo projeto", sem execução).

### 5.1 Taxonomia

| Classe | Exemplos | Traço definidor |
| :--- | :--- | :--- |
| **Runtime de agentes** | Herdr | O servidor é dono dos PTYs; toda UI é cliente |
| **Gerenciador de sessão/worktree sobre tmux** | workmux, Agent of Empires, Claude Squad, Agent Deck, worktrunk, **esta stack (`awt`+`acpd`)** | Camada fina sobre um multiplexador existente |
| **Visualizador** | Age of Agents | Exibição ambiente somente leitura |
| **"ADE" em GUI** | Orca, Conductor, Emdash, Superset | Janela de app |
| **Gerenciador de arquivos / picker** | Yazi, superfile, lf, television, **`wm`**, fzf+zoxide | Navegação/preview/ações |
| **TUI de Git** | lazygit, gitui, jjui, **`lazygitrs`** | Loop de revisão |

### 5.2 Matriz de orquestração de agentes

| | **Esta stack** | **Herdr 0.9.3** | **workmux** | **Agent of Empires** | **Age of Agents** | **Claude Squad** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stars / licença / linguagem | 0 / mista / Rust+sh | **42,5k** / Apache-2.0 / Rust | 2,8k / MIT / Rust | 3,3k / MIT / Rust | 264 / sem licença / TS | 8,6k / AGPL-3.0 / Go |
| Idade | meses | 6 meses (2026-03) | 11 meses | 9 meses | 4 meses | 19 meses |
| Substrato | tmux 3.7c | Servidor + PTY próprios | tmux (+WezTerm/kitty/Zellij) | tmux | nenhum (lê dados de sessão) | tmux |
| Sobrevive a crash/detach da UI | ✅ (tmux) | ✅ (servidor) | ✅ (tmux) | ✅ (tmux) | n/a | ✅ |
| Restauração de layout/agente após **reboot** | ⚠️ só layout (estilo resurrect); sem retomada de agente | ✅ layout + retoma agentes suportados (os processos em si não sobrevivem) | ⚠️ preso ao tmux | ⚠️ preso ao tmux | n/a | ⚠️ |
| Modelo de worktree | **1 worktree = 1 *sessão* tmux** | suporte a worktree no runtime | **janela por padrão; existe modo `--session`** | worktrees | nenhum | worktrees |
| Fonte do estado do agente | **Hooks estruturados → `acpd`** | manifests de detecção (22 CLIs) **+ integrações por agente** | hooks → ícones de status; "sem saída 10 s ⇒ interrompido" | monitor de status (running/waiting/idle) | logs de sessão locais | baseado em tela |
| Loop de revisão | **✅ `lazygitrs` dual-diff + nota → agente** | não declarado | dashboard "revisar mudanças" | diffs na web | ❌ | visão de diff |
| Remoto / mobile | Tailscale+SSH (manual, [doc](../architecture/remote-agent-workflow-acpd.md)) | **✅ máquinas SSH salvas, lista unificada de agentes, cliente mobile** | via tmux/SSH | **✅ dashboard web (mobile)** | ❌ | ❌ |
| Sandbox | `ai-jail` (docs) | não declarado | **✅ container / Lima** | **✅ Docker** | ❌ | ❌ |
| Chrome persistente | **0 colunas** (popups) | sidebar/lista de workspaces (largura não verificada) | ícones no nome da janela; **`sidebar` opcional** | TUI em tela cheia | segundo monitor | TUI |
| Controle programático | JSON-RPC (`acpd`), `tmux.*` | **CLI + socket API, "esperar até bloquear"** | CLI, skills | CLI | WebSocket (leitura) | CLI |
| Plugins | scripts | **1.548 plugins da comunidade** | hooks YAML | — | — | — |
| Doutrina de teclado | **Home row, sem Alt, `keyd`** | prefixo estilo tmux **+** mouse de primeira classe | padrões do tmux | teclas da TUI | n/a | teclas da TUI |

### 5.3 Veredito por ferramenta ("o que roubar")

**Herdr (o concorrente de verdade).** 42,5k stars e 1,29M de instalações em seis meses é um impulso que esta stack não alcança; a tese — *terminais persistem num servidor, UIs são clientes descartáveis* — é sólida e inclui restauração após reboot, listas multi-máquina e API nativa para agentes. A caracterização dos docs anteriores (monólito, só PTY scraping, "quebra a navegação do Neovim", "sidebar de 32 colunas") está **parcialmente defasada ou não verificada** (a árvore de código tem `src/detect/manifests` *e* `src/integration/{claude_settings,opencode_config}.rs`, ou seja, integrações em nível de config). **Não migrar** — popups, `vim-tmux-navigator`, `sesh`, integração do `lazygitrs` e a doutrina home-row são ativos reais e funcionando (Zero-Churn). **Copiar três ideias:**
1. uma **primitiva `wait`** — RPC `agentState/wait {pane, state, timeout}` (long-poll) para agentes/scripts se orquestrarem;
2. **retomada de agente pós-reboot** — persistir `{pane, CLI do agente, session id}` e reemitir o comando de resume do agente;
3. **lista de frota multi-host** — um `acpd` por host + agregador via Tailscale (P3).

**workmux.** A crítica anterior ("1 worktree = 1 janela") está **obsoleta**: tem modo `--session`, sessões multi-janela, sidebar opcional, dashboard, sandboxes container/Lima, nomes de branch via LLM, hooks `pre_merge`/`post_create` e 4 backends. Onde ainda difere: sem doutrina home-row, sem loop de review notes, sem camada de popups. **Roubar:** integração de sandbox, limpeza de status ao focar, a heurística de "interrompido" aos 10 s (endurecimento barato para a varredura de stale de 30 s do `acpd`) e um gate `pre_merge` (`just check`) no `awt ship`.

**Agent of Empires.** O irmão filosoficamente mais próximo (camada Rust fina sobre tmux, worktrees, sandbox Docker) mais um **dashboard web utilizável do celular**. **Roubar:** o caminho de aprovação mobile (um endpoint autenticado pequeno no `acpd` atrás de `tailscale serve`). Não vale adotar por inteiro — sobrepõe `awt`+`acpd` sem o loop de revisão.

**Age of Agents.** Uma visão pixel-art, somente leitura, de segundo monitor, alimentada por WebSocket local (264 stars; 4 meses; licença não declarada). Contra o próprio argumento de atenção do repo (movimento periférico dispara reflexo de orientação), é **negativo líquido para flow focado** e não adiciona controle. Aceitável só como visão ambiente *opcional* de segundo monitor; **não** substitui o `acpd`.

**Outros.** Claude Squad (8,6k★, AGPL, flag de auto-accept), Agent Deck (1k★, dashboard de frota/custo), worktrunk (8,9k★, CLI de worktree — já empacotado aqui), ADEs em GUI (Orca 85,9k★ mas 7,7k issues abertas; presos ao app pela própria taxonomia do Herdr — **não** reverificado). Nenhum oferece o loop de revisão nem a doutrina ergonômica.

### 5.4 Gerenciadores de arquivos e pickers

| | **`wm` (waymaker 0.2.0)** | **Yazi 26.9.1** | **superfile** | **lf** | **television** | **fzf + zoxide** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stars / linguagem / licença | 0 / Rust / AGPL-3.0 | **42,6k** / Rust / MIT | 23,7k / Go / MIT | 9,5k / Go / MIT | 6,3k / Rust / MIT | 83,4k + 39,9k / Go + Rust / MIT |
| Start-up (`--version`, média de 30, piso 1,9 ms) | **6,0 ms** | 8,6 ms | não instalado | não instalado | não instalado | fzf 9,3 ms, zoxide 2,3 ms |
| Modelo central | Picker Nucleo SIMD; walker in-process; frecency `redb` | **I/O totalmente assíncrono**, agendador de tarefas, CPU multi-thread | Multi-painel, estilo GUI | Mínimo, scriptável em shell | TUI fuzzy por canais | Filtro de linhas + base de frecency |
| Previews | Mídia Kitty/Sixel/iTerm2, Markdown + Mermaid, árvore | Realce de código, imagem/vídeo/PDF, pré-carregamento | Embutido | Externo | Previews por canal | `--preview` |
| Operações de arquivo | criar / renomear / lixeira / copiar-recortar-colar / comprimir / **pilha de undo** | rename em lote, extrair, modo visual, abas, seleção entre diretórios, VFS | operações completas | via scripts | nenhuma | nenhuma |
| Extensibilidade | Presets TOML | **Plugins Lua, gerenciador de pacotes, DDS pub/sub** | plugins/temas | shell | canais TOML | shell |
| Encaixe com shell/ZLE | **Melhor: buffer object-first, `Tab`-jump, fonte tri-modal** | `--chooser-file`, plugin `zoxide` | fraco | ok | ok | excelente |
| Filtro headless (384k linhas) | **610 ms** | n/a | n/a | n/a | n/a | `fzf` **125 ms** |

Veredito: **o `wm` vence como *picker/navegador integrado a ZLE e tmux*; o Yazi vence com folga como *gerenciador de arquivos*** (agendador async, 3+ anos de maturidade, ecossistema de plugins, VFS). O `fm.rs` + visualizadores de mídia/Markdown são escopo excessivo para um fork de 0 stars e mantenedor único. Recomendação: **congelar o `fm.rs`**, manter o `yazi` (já instalado) como saída de emergência para operações em lote/remotas/previews pesados, e decidir por dados: registrar contagens das ações `a/r/d/y/p/z` por 4 semanas ([§10.3](#103-instrumentação-n-de-1)); se raras, parar de investir.

### 5.5 TUIs de Git

| | **`lazygitrs` (fecavmi)** | lazygit | gitui | jjui |
| :--- | :--- | :--- | :--- | :--- |
| Stars / linguagem | 0 (upstream Blankeos 32) / Rust | **82,9k** / Go | 22,5k / Rust | 2,2k / Go (jujutsu) |
| Issues abertas | 0 | 1.047 | 347 | 42 |
| Start-up | **2,7 ms** | não instalado | não instalado | não instalado |
| Único aqui | Dual-diff `C-g` (arquivos ↔ HEAD), diff combinado de diretório, **review note → pane do agente**, isolamento `.lazygitrs.port` | Mindshare, maturidade | Velocidade, segurança | Fluxos do jujutsu |
| Saúde do fork | **81 à frente / 3 atrás** do upstream, 168 testes | — | — | — |

Veredito: o loop de revisão é o diferencial mais forte da stack, e o lugar mais barato para atacar o custo de compreensão ([§4.3](#43-lei-de-amdahl-para-o-flow-e-a-correção-do-fan-out)). Manter o fork rebaseado; tentar **enviar ao upstream** o dual-diff e o recurso de notas para reduzir a dívida do fork.

### 5.6 Terminal e multiplexador

Ghostty 1.3.1 (61,9k★, Zig), tmux 3.7c (49,8k★, C), Zellij (35,7k★, Rust, plugins WASM, floating panes *persistentes*, ressurreição de sessão). A lei do eixo Z depende de `display-popup -E` **efêmero**; floats do Zellij são panes persistentes, então migrar mudaria o modelo sem ganho medido. Não existem números autoritativos atuais de latência de terminal para o Ghostty (o estudo do Dan Luu é anterior) — **meça você mesmo** ([§9.3](#93-como-medir-direito)). **Manter tmux + Ghostty.**

---

## 6. Seção 5 — Código de implementação pronto para produção

Todos os trechos abaixo tiveram a sintaxe checada (`bash -n`) e, quando indicado, foram executados nesta máquina. **Nenhum foi aplicado ao repo ou ao sistema** por esta auditoria.

### (a) Corrigir o F1 — resolver um `lazygitrs` *capaz* no `lazygitrs-popup.sh`

Substituir as duas linhas de `LZG_BIN` por um resolvedor que pula binários sem `--commits`. Testado: resolve `~/.local/bin/lazygitrs` (v0.0.38); uma cópia só da v0.0.20 é corretamente rejeitada; a sonda custa ≈ 4,5 ms (cachear o resultado numa opção do tmux se quiser).

```bash
resolve_lzg() {
  local c
  for c in "$HOME/.local/bin/lazygitrs" "$(command -v lazygitrs 2>/dev/null)" "$HOME/.cargo/bin/lazygitrs"; do
    [ -x "$c" ] || continue
    "$c" --help 2>&1 | grep -q -- '--commits' && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
LZG_BIN="$(resolve_lzg)" || { tmux display-message "lazygitrs >= 0.0.3x not found (stale ~/.cargo/bin?)"; exit 0; }
```

Alternativa mais simples: `rm ~/.cargo/bin/lazygitrs` (ou `cargo uninstall lazygitrs`). **Não** faça isso com o `acpd`: `~/.local/bin/acpd` é um symlink para `~/.cargo/bin/acpd` de propósito.

### (b) Corrigir o F2 — reaplicar a config do `keyd` (requer `sudo`)

```bash
sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
[global]
overload_tap_timeout = 200

[ids]

*

[main]

capslock = overload(control, esc)
EOF
sudo keyd reload
```

Depois confirme: `grep overload_tap_timeout /etc/keyd/default.conf`.

### (c) F4 — profundidade de scrollback

```tmux
set -g history-limit 50000
```

### (d) Entrega de som por breakpoint (protótipo, não testado ponta a ponta)

Adia um chime até o operador pausar a digitação (Iqbal & Bailey, grau B). `#{client_activity}` tem **resolução de 1 segundo**, daí `idle_needed ≥ 2`.

```bash
#!/usr/bin/env bash
# chime-at-breakpoint.sh <wav> — defer an audible cue until typing pauses (max ~MAX_WAIT s)
idle_needed=${IDLE_NEEDED:-2}; max_wait=${MAX_WAIT:-20}; ticks=0
while (( ticks < max_wait * 2 )); do
  act=$(tmux display-message -p '#{client_activity}' 2>/dev/null) || break
  printf -v now '%(%s)T' -1
  (( now - act >= idle_needed )) && break
  sleep 0.5; ticks=$(( ticks + 1 ))
done
exec pw-play "$1"
```

Para `permission`/`error`, decida se devem tocar imediatamente também no modo Focus (política, [§10.2](#102-dois-modos-de-flow-não-um)).

### (e) Telemetria pessoal zero-fork (testado: logger + sumarizador)

`~/.config/tmux/flow-log.sh` (usa o builtin `printf '%(%s)T'` — sem fork de `date`):

```bash
#!/usr/bin/env bash
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/flow"
printf '%(%s)T\t%s\t%s\n' -1 "$1" "${2:-}" >> "${XDG_STATE_HOME:-$HOME/.local/state}/flow/events.tsv"
```

```tmux
set-hook -g client-session-changed "run-shell -b \"~/.config/tmux/flow-log.sh session '#{session_name}'\""
set-hook -g after-select-window    "run-shell -b \"~/.config/tmux/flow-log.sh window  '#{session_name}:#{window_index}'\""
```

Trocas por hora:

```bash
awk -F'\t' '$2=="session"||$2=="window"{h=int($1/3600); n[h]++} END{for(k in n) printf "%s\t%d\n", strftime("%F %H:00",k*3600), n[k]}' \
  ~/.local/state/flow/events.tsv | sort
```

(A lógica de buckets do `awk` foi testada com dados sintéticos; `strftime` exige `gawk`.)

### (f) Doctor de desvios — teria pego F1, F2, F4 (testado; sai com 1 em qualquer WARN)

O `acpd` está **deliberadamente excluído** (F10: `acpd --version` inicia um daemon).

```bash
#!/usr/bin/env bash
rc=0; warn(){ printf 'WARN  %s\n' "$*"; rc=1; }; ok(){ printf 'ok    %s\n' "$*"; }
for b in lazygitrs wm; do
  declare -A seen=(); n=0
  for p in "$HOME/.local/bin/$b" "$HOME/.cargo/bin/$b" "$(command -v "$b" 2>/dev/null)"; do
    [ -x "$p" ] || continue
    v=$("$p" --version 2>&1 | head -n1)
    [ -z "${seen[$v]:-}" ] && { seen[$v]="$p"; n=$((n+1)); }
  done
  (( n > 1 )) && warn "$b: $n versions on disk: $(printf '%s | ' "${!seen[@]}")" || ok "$b: single version"
  unset seen
done
grep -q overload_tap_timeout /etc/keyd/default.conf 2>/dev/null && ok "keyd tap timeout" \
  || warn "keyd: live config lacks overload_tap_timeout (installer sets 200)"
hl=$(tmux show -gv history-limit 2>/dev/null || echo 0)
(( hl >= 30000 )) && ok "tmux history-limit=$hl" || warn "tmux history-limit=$hl (<30000)"
exit $rc
```

Resultado nesta máquina hoje: `lazygitrs` WARN (0.0.38 vs 0.0.20), `wm` ok, `keyd` WARN, `history-limit` WARN, saída 1.

### (g) Proposta de política para o `acpd` (só design — não implementada)

```toml
[policy]
wip_limit = 4                  # soft cap; exceeding plays one low "slot-full" cue
mode = "triage"                # "focus" | "triage"

[policy.focus]
audible = ["permission", "error"]   # suppress response/question chimes; badges still update
defer_to_breakpoint = true

[policy.triage]
audible = ["response", "question", "permission", "error"]
defer_to_breakpoint = false
```

Expor `acpd-cli mode focus|triage` e mostrar o modo como um glifo na barra de status. Adicionar também o RPC `agentState/wait` e a reidratação de estado a partir das opções de pane `@ai_agent_state_*` do tmux na inicialização ([§11 P1](#p1--dias)).

### (h) Harness de benchmark reprodutível (executado para produzir a [§9](#9-relatório-de-desempenho))

```bash
bench(){ local n=30 s e; s=$(date +%s%N); for _ in $(seq $n); do "$@" >/dev/null 2>&1; done; e=$(date +%s%N)
         echo "$(( (e-s)/n/1000 )) us/run :: $*"; }
bench /bin/true; bench wm --version; bench lazygitrs --version; bench yazi --version; bench fzf --version; bench zoxide --version; bench tmux -V
# headless filter, best of 5
find /usr "$HOME/dev" -type f 2>/dev/null | head -400000 > /tmp/paths.txt
for f in 10000 100000 400000; do head -$f /tmp/paths.txt > /tmp/p.txt
  for tool in "fzf --filter zshfun" "wm -f zshfun"; do best=99999
    for _ in 1 2 3 4 5; do s=$(date +%s%N); $tool < /tmp/p.txt >/dev/null 2>&1; e=$(date +%s%N); d=$(( (e-s)/1000000 )); (( d < best )) && best=$d; done
    echo "$f lines :: $tool :: ${best} ms"; done; done
# authorized acpd RPC latency (token lives in $XDG_RUNTIME_DIR)
T=$(cat "$XDG_RUNTIME_DIR/acpd/token")
curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' -X POST http://127.0.0.1:4040/rpc \
  -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"agentState/list","params":{},"id":1}'
```

---
