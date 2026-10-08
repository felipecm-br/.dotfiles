# Reavaliação do Workflow para Estado de Flow — Pós-Ajustes e Comparação com workmux & Concorrentes

> **Versão em português, sem canônico em inglês** (esta é uma reavaliação; a base canônica continua sendo [`workflow-flow-state-audit.md`](../architecture/workflow-flow-state-audit.md), de 2026-10-05, em inglês, com tradução em [`workflow-flow-state-audit-pt.md`](workflow-flow-state-audit-pt.md)).
> **Data:** 2026-10-08 · **Escopo:** `keyd` → Ghostty → tmux → `waymaker` (`wm`) → `lazygitrs` (branch `fecavmi`) → `acpd` → `awt`, contra **workmux**, Herdr, Agent of Empires, Claude Squad, worktrunk, Age of Agents, Yazi, lazygit e afins.
> **Relação com os docs existentes:** atualiza o placar, o status dos achados F1–F10 e a tabela competitiva. O plano de execução continua em [`flow-state-implementation-plan.md`](../architecture/flow-state-implementation-plan.md). A doutrina ergonômica do [manifesto](../architecture/terminal-ergonomics-and-ux-manifesto.md) é mantida (Regra Zero-Churn).

---

## 0. Método, graus de evidência e limites

| Grau | Significado |
| :---: | :--- |
| **A** | Medido, lido ou executado diretamente nesta máquina / no código-fonte durante esta reavaliação. |
| **B** | Declarado pelo projeto (README, site, API do GitHub) e lido hoje, mas **não executado** aqui. |
| **C** | Julgamento meu ou conhecimento de base, **não** reverificado. Tratar como hipótese. |

**Limites (leia antes de confiar em qualquer número):**

- Todas as medições vêm de **uma máquina**, melhor-de-N ou média-de-N, sem `hyperfine` e sem fixar CPU. São direcionais.
- **As medições desta rodada não são comparáveis em valor absoluto com as de 2026-10-05.** O piso de spawn (`/bin/true`) caiu de 1,88 ms para 0,45 ms: a máquina estava mais ociosa hoje. Só razões entre ferramentas medidas **na mesma rodada** têm algum valor ([§3.4](#34-desempenho-remedido)).
- Fatos sobre concorrentes vêm do README do workmux (lido hoje) e da API pública do GitHub (stars, licença, último push, última release — lidas hoje). **Nada foi instalado nem executado** dos concorrentes. Fatos de Herdr, Agent of Empires, Age of Agents e Claude Squad **não foram relidos** hoje além dos números da API; o restante vem da auditoria de 05/10.
- As notas da [§5](#5-placar-revisado) são **julgamento (C)** contra um critério explícito, não medição.
- Esta reavaliação **não mede fluxo**: ela mede defeitos corrigidos, desvios e capacidades. Se o fluxo melhorou, só a telemetria pessoal ([§3.5](#35-telemetria-pessoal-ainda-sem-dados-suficientes)) poderá dizer.

---

## 1. Resumo executivo

### 1.1 Veredito

Em 05/10 o veredito foi "cockpit de primeira linha para um único operador, mas **ainda não é o ápice**" por causa de defeitos verificados no sistema ao vivo. Três dias depois:

- **Todos os defeitos de configuração e desvio (F1, F2, F3, F4, F6, F10) estão corrigidos e verificados**; o `drift-doctor` sai com código 0 (grau A).
- O **loop de revisão**, que era o diferencial mais forte e estava quebrado como instalado (nota 4,0), voltou a funcionar e ganhou duas alavancas contra o custo de compreensão: **fila de arquivos ordenada por risco** e **badge de resultado de testes** no cabeçalho do commit.
- O que **não mudou** é o eixo mais fraco: **resiliência/portabilidade** (estado do `acpd` só em memória, sem retomada de agentes após reboot, só Linux) e **medição** (telemetria existe, mas com ~2 dias de dados).

Contra o **workmux** (o concorrente direto mais próximo em filosofia), a conclusão honesta é:

> Em *ergonomia, supervisão estruturada e loop de revisão* esta stack é **mais profunda**. Em *maturidade, portabilidade, sandbox, instalação e ecossistema* o workmux é **claramente superior** — e já cobre, de forma nativa, três coisas que aqui ainda são pendência (sandbox, heurística de "interrompido", auto-clear de status ao focar).

### 1.2 Placar (antes × depois)

Pesos idênticos aos da auditoria de 05/10. Critério na [§5.1](#51-critério-e-pesos).

| Dimensão | Peso | 05/10 instalado | **08/10 instalado** | 08/10 design |
| :--- | :---: | :---: | :---: | :---: |
| Biomecânica de entrada | 15 | 8,5 | **8,8** | 9,0 |
| Latência / responsividade | 15 | 8,0 | **8,5** | 9,0 |
| Navegação zero fricção | 10 | 9,0 | **9,0** | 9,0 |
| Loop de revisão Git/IA | 20 | 4,0 | **8,0** | 9,2 |
| Supervisão e telemetria de agentes | 15 | 8,0 | **8,2** | 8,5 |
| Semiótica visual / cognição | 5 | 8,0 | **8,3** | 8,3 |
| Resiliência, portabilidade, remoto | 10 | 5,5 | **5,5** | 6,0 |
| Medição e disciplina de evidência | 5 | 4,0 | **5,5** | 6,0 |
| Manutenibilidade / bus factor | 5 | 5,0 | **5,0** | 5,0 |
| **Geral ponderado** | 100 | **6,8**¹ | **7,8** | **8,3** |

¹ O placar original publicou 6,9 (instalado) e 8,0 (design). Recalculando as notas originais com os mesmos pesos dá 6,8 e 8,1; a diferença é arredondamento da tabela original. Uso o valor recalculado como linha de base.

**O ganho (+1,0 ponto instalado) vem quase todo de uma linha:** o loop de revisão (4,0 → 8,0, peso 20) deixou de estar quebrado. Isso é a correção de um defeito, não uma melhoria de fluxo mensurada.

---

## 2. O que mudou desde a auditoria de 05/10

### 2.1 Status dos achados F1–F10 (verificado hoje, grau A)

| ID | Achado | Status | Evidência / observação |
| :-: | :--- | :---: | :--- |
| F1 | Popup `Ctrl+G` usava `lazygitrs` obsoleto | ✅ **Corrigido** | [`lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh) agora resolve o binário por capacidade (`resolve_lzg`: exige `--commits` em `--help`), na ordem `~/.local/bin` → `PATH` → `~/.cargo/bin`. Hoje os dois binários são idênticos (v0.0.38), então o defeito já estava latente; o resolvedor impede a recorrência. |
| F2 | `/etc/keyd/default.conf` sem `overload_tap_timeout` | ✅ **Corrigido** | `drift-doctor` confirma `overload_tap_timeout` presente após reaplicar a config. |
| F3 | Debounce documentado como 300/400/650 ms | ✅ **Corrigido hoje** | A correção anterior era **parcial**: esta reavaliação ainda encontrou "400 ms" em [`popup-isolation-and-debounce.md`](../tmux/popup-isolation-and-debounce.md) (apontando também o arquivo errado: o debounce vive em `api.rs`, padrão 650 ms em `daemon.rs`) e em [`smart-patterns-roadmap.md`](../architecture/smart-patterns-roadmap.md). Ambos corrigidos agora. Resta uma menção a **300 ms** em [`open-source-ai-tmux-stack-plan.md`](../architecture/open-source-ai-tmux-stack-plan.md), em um *changelog histórico* de uma correção passada — mantida de propósito. |
| F4 | `history-limit 10000` | ✅ **Corrigido** | `tmux show -gv history-limit` = `50000` ao vivo. |
| F5 | `wm -f` mais lento que `fzf --filter` | ⏳ **Pendente** | Razão relativa **não melhorou** ([§3.4](#34-desempenho-remedido)). |
| F6 | `git status` síncrono no pré-check do popup | ✅ **Corrigido** | Trocado por `git diff --quiet` + `git diff --cached --quiet` + `ls-files --others --exclude-standard \| head -n1` (sai no primeiro arquivo sujo). Teste manual: árvore limpa → abre em commits; arquivo untracked criado → abre em Files. |
| F7 | Resíduos de Alt / acordes hostis | 🟡 **Parcial** | Removidos do **repo** `alt+shift+enter` e `super+control+shift+alt+arrow_*` do Ghostty. **Não aplicado ao sistema vivo** ([N1](#n1--a-mudança-do-ghostty-está-só-no-repositório)). Hyprland mantém 15 linhas com `ALT`. |
| F8 | Licenciamento (`waymaker` AGPL vs upstream `NOASSERTION`; `acpd` sem licença) | ⏳ **Pendente** | Não tocado. |
| F9 | Bus factor / `acpd` com 11 testes | ⏳ **Pendente** | Contagem de `#[test]`/`#[tokio::test]` em `acpd/src`: **11** (inalterada). |
| F10 | `acpd --version` subia um daemon | ✅ **Corrigido** | `--version`/`-V`, `--help`/`-h` e `health` tratados **antes** de inicializar tracing, PID file ou rede. |

**Nota de implementação (F10):** a correção foi um *fast-path manual* em `main.rs`, **não** o `clap` proposto no plano. Cobre `--version`, `--help`, `--config`/`-c`/`--config=` e o subcomando `health`, mas não gera `--help` automático por subcomando nem validação de argumentos desconhecidos. É adequado ao escopo atual; migrar para `clap` só vale se a CLI crescer (`mode`, `wait`...).

### 2.2 Itens do roadmap de 05/10

| Item | Status | Observação |
| :--- | :---: | :--- |
| `drift-doctor` ([`scripts/drift-doctor.sh`](../../scripts/drift-doctor.sh)) | ✅ | Audita capacidade do `lazygitrs`, drift de binários `wm`/`acpd`, `keyd`, `history-limit` e RPC do `acpd`. **Saída 0 hoje.** Ainda **não** está ligado a login/CI. |
| Telemetria pessoal zero-fork | ✅ | [`flow-log.sh`](../../tmux/.config/tmux/flow-log.sh) ativo via hooks do tmux. |
| `permission` ≠ `error` (cor) | ✅ | `permission` laranja, `error` vermelho em [`acpd.toml.tpl`](../../acpd/.config/omarchy/themed/acpd.toml.tpl). Fallback ASCII para SSH **não verificado** hoje. |
| Fila de revisão por risco | 🟡 | Entregue como heurística de **caminho** ([N4](#n4--a-ordenação-por-risco-é-uma-heurística-de-caminho-e-muda-a-ordem-da-lista)). |
| Testes antes do diff (badge) | 🟡 | Parser e render entregues, mas **sem produtor** dos trailers ([N3](#n3--o-badge-de-testes-está-dormente)). |
| Gate `pre_merge` (`just check`) | ✅ | No hook [`pre-merge.sh`](../../awt/.config/waymaker/hooks/pre-merge.sh); só dispara se o repo tiver `justfile` com receita `check` e `just` instalado. |
| Sino por breakpoint | 🟡 | Script [`chime-at-breakpoint`](../../utils/.local/bin/chime-at-breakpoint) existe; **não integrado** ao `acpd`. |
| `agentState/wait` + reidratação de estado | ⏳ | Não iniciado. |
| Retomada de agentes pós-reboot | ⏳ | Não iniciado. |
| Sandbox no `awt` | ⏳ | Não iniciado (workmux já tem — [§4](#4-comparação-com-o-workmux)). |
| Modo **Triage** / alternância Focus/Triage | ❌ **Descartado** | **Decisão do dono:** o cockpit já cumpre o papel de triagem; a chave de modo não será implementada. Remove o item do roadmap. |

---

## 3. Achados desta reavaliação

### 3.1 Resumo

| ID | Achado | Severidade | Grau |
| :-: | :--- | :---: | :---: |
| N1 | Mudança do Ghostty está só no repositório; o arquivo vivo diverge e o `stow` não adota | Média | A |
| N2 | `acpd` em execução ainda é o binário antigo; reiniciar perde o estado em memória | Média | A |
| N3 | Badge de testes está dormente (nada escreve os trailers) | Média | A |
| N4 | Ordenação por risco é heurística de caminho e altera a ordem da lista de Files | Baixa | A |
| N5 | 7 pacotes têm conflito de `stow` pré-existente | Média | A |

### N1 — A mudança do Ghostty está só no repositório

`~/.config/ghostty/config` **não é um symlink**: é um arquivo regular. `./stow.sh -n` reporta conflito para o pacote `ghostty` (*"cannot stow … over existing target … since neither a link nor a directory and --adopt not specified"*). O `diff` entre o arquivo vivo e o do repo mostra, além dos binds removidos, uma divergência de fonte: **vivo = `JetBrainsMono Nerd Font`, repo = `JetBrainsMono Nerd Font Propo`**. Adotar com `--adopt` ou sobrescrever **mudaria a fonte do terminal** sem que isso seja o objetivo.

Consequência: F7 está **corrigido no repo, não "como instalado"**. Decisão pendente do dono: qual fonte é a correta, e só então adotar.

### N2 — `acpd` em execução ainda é o binário antigo

O serviço (PID 1213) foi iniciado às 05:42; o binário foi recompilado às 09:20. O CLI novo (`acpd --version`, `acpd health`) funciona porque é outro processo, mas o **daemon continua rodando o código antigo** até um `systemctl --user restart acpd`. Como o estado dos agentes vive só em memória (F9), **reiniciar zera os badges até o próximo hook de cada pane**. Esta é a razão concreta para fazer a **reidratação a partir das opções de pane `@ai_agent_state_*` antes do próximo restart**, não depois.

### N3 — O badge de testes está dormente

O `lazygitrs` agora lê `Test-Status:`, `Tests:`, `Test:` ou `CI:` da mensagem do commit e renderiza `✔ Tests: …` / `✘ Tests: …`. **Mas nada no fluxo escreve esses trailers**: uma busca por `Test-Status`/`Tests:` nos pacotes `awt`, `agents-skills`, `.agents`, `utils` e `git` do repositório não encontra nenhum produtor (grau A). Sem produtor, a alavanca 2 da [§4.3 da auditoria](../architecture/workflow-flow-state-audit.md#43-amdahls-law-for-flow-and-the-fan-out-correction) existe como capacidade de exibição, **não como efeito**. Também é um sinal **declarado pelo autor do commit**, não um resultado verificado: um agente pode escrever `Tests: pass` sem ter rodado nada.

Próximo passo coerente: o hook `pre-merge` (que já roda `just check`) ou o próprio `awt` gravar o trailer com o **resultado real**.

### N4 — A ordenação por risco é uma heurística de caminho e muda a ordem da lista

`review_priority()` classifica **só pelo nome do arquivo** em 3 níveis (código/config → testes e docs → lockfiles, snapshots, minificados e binários). A proposta original era *churn × centralidade × ausência de teste*; **isso não foi implementado**. Efeitos a observar:

- Ordena a lista **plana** de Files (`git/file.rs`), a lista de arquivos de commit (`git/diff.rs`) e as folhas da **árvore** (`sort_dirs_first`). Antes a ordem era a do `git status`/alfabética; agora arquivos de Tier 1 sobem. **É uma mudança na ordem a que a memória espacial estava habituada.** Se incomodar, a ordenação é reversível removendo as três chamadas a `review_priority` (`git/file.rs`, `git/diff.rs`, `model/file_tree.rs`). Atenção: o commit `dc5925b69` do `lazygitrs` **junta ordenação e badge**; reverter o commit inteiro remove os dois.
- Não há coluna visível indicando o tier; o operador não vê *por que* um `Cargo.lock` foi para o fim.
- `.md` e `.txt` caem no Tier 2 mesmo quando são o próprio objeto da revisão (como neste repo de dotfiles). Pode merecer exceção por repositório.

### N5 — 7 pacotes têm conflito de `stow` pré-existente

`./stow.sh -n` (hoje) falha em: `acpd`, `alacritty`, `antigravity`, `ghostty`, `hypr`, `kitty`, `zsh-plugins`; os outros 50 passam. Não foi causado por esta sessão, mas mostra que **o repositório não é a fonte única de verdade para esses pacotes**: arquivos vivos existem fora do controle do Stow. Isso é exatamente a classe de desvio que o `drift-doctor` deveria pegar e **hoje não pega**. Candidato a nova checagem.

### 3.4 Desempenho remedido

Mesma metodologia da §9 da auditoria (média de 30 execuções de `--version`; melhor de 5 para filtro headless). **Atenção ao limite da §0: o piso de spawn mudou (1,88 → 0,45 ms).**

| Métrica | 05/10 | **08/10** | Leitura |
| :--- | ---: | ---: | :--- |
| Piso `/bin/true` | 1,88 ms | **0,45 ms** | Máquina mais ociosa hoje; **absolutos não são comparáveis** |
| `lazygitrs --version` | 2,66 ms | **0,66 ms** | |
| `wm --version` | 5,97 ms | **0,99 ms** | |
| `acpd --version` | *não medível (F10)* | **1,11 ms** | Agora medível e inofensivo |
| `tmux -V` | 5,15 ms | **1,49 ms** | |
| `fzf --version` | 9,30 ms | **2,09 ms** | |
| `zoxide --version` | 2,27 ms | **0,76 ms** | |
| `yazi --version` | 8,63 ms | **10,28 ms** | Único que *subiu*; ruído provável (C) |
| Filtro headless 10k: `fzf` / `wm` | 11 / 25 ms | **2 / 6 ms** | Resolução de 1 ms: razão pouco confiável |
| Filtro headless 100k: `fzf` / `wm` | 43 / 155 ms | **9 / 37 ms** | **Razão 4,1× (era 3,6×)** |

**Leitura honesta:**

1. Todo binário do caminho de interação inicia em **~1 ms** acima do piso. O orçamento de 100 ms (Miller/Card) não é ameaçado por *start-up*.
2. **F5 não foi resolvido.** Em valor absoluto o `wm -f` a 100k linhas (37 ms) está abaixo de 100 ms *nesta rodada ociosa*, mas a **razão contra `fzf` não melhorou** (3,6× → 4,1×). A extrapolação "cruza 100 ms perto de 60k linhas" vale só para a máquina carregada de 05/10. Reclassifico F5 de "defeito de latência" para **"ineficiência relativa; gargalo só sob carga ou árvores grandes"** (C — não medi 384k linhas hoje).
3. O pré-check do popup (F6) agora sai no primeiro arquivo sujo; não re-cronometrei em worktree grande com cache frio, então o ganho em **monorepo** continua **C**.

### 3.5 Telemetria pessoal: ainda sem dados suficientes

`~/.local/state/flow/events.tsv` tem **145 linhas** cobrindo ~2 dias (07–08/10). Trocas de sessão/janela por hora variam de 4 a 22 nas horas com dados. **É cedo demais para qualquer conclusão** (a auditoria pedia ≥ 2 semanas). Além disso o log só captura **trocas de sessão/janela**: não captura latência `waiting → humano respondeu`, tempo de revisão por commit nem a maior janela ininterrupta — que são as métricas que de fato respondem se o fluxo melhorou ([§10.3 da auditoria](../architecture/workflow-flow-state-audit.md#103-n-of-1-instrumentation)).

---

## 4. Comparação com o workmux

O workmux é o concorrente direto mais relevante: mesma tese (*"build on tools you already use"* — tmux + git worktrees + seu agente), mesma linguagem (Rust), mesma ideia de ciclo de vida de worktree. Há inclusive compatibilidade prática: o hook `pre-merge` do `awt` lê `.workmux.yaml` como fallback de `.awt.toml` (grau A, arquivo lido).

**Dados do projeto (API do GitHub + README, 2026-10-08, grau B):** 2,8k estrelas · MIT · 61 issues abertas · último push 2026-10-04 · última release `v0.1.271` (2026-10-04) · suporta tmux, **WezTerm, kitty e Zellij** como backends · instalação via script, **Homebrew, Cargo, mise e Nix**.

### 4.1 Matriz dimensão a dimensão

| Dimensão | **Esta stack (`awt` + `acpd` + cockpit)** | **workmux** | Quem leva |
| :--- | :--- | :--- | :---: |
| **Modelo de worktree** | 1 worktree = 1 sessão tmux | 1 worktree = 1 **janela** (padrão); `--session` cria sessão | Empate (ambos suportam sessão) |
| **Ciclo de vida** | `awt` new / merge / pr / rebase / delete / rename / sweep / reap (scripts em [`awt/`](../../awt/README.md)) | `add` / `merge` (mescla, apaga worktree, fecha janela, remove branch) em um comando | Empate; workmux mais enxuto, `awt` cobre PR e rebase |
| **Hooks de ciclo de vida** | `post-create`, `pre-merge`, `post-merge`, `pre-remove` (+ `.awt.toml`, fallback `.workmux.yaml`) | `post_create`, `pre_merge` (aborta em falha), `pre_remove`, com variáveis `WM_*` | Empate |
| **Gate de qualidade no merge** | `just check` se existir receita + `docs-lint.sh` no `.dotfiles` | `pre_merge` configurável por YAML | Empate (mecanismo equivalente; o do `awt` é mais *implícito*) |
| **Estado do agente** | **Hooks estruturados → `acpd`** (working/question/permission/error/idle), RPC JSON | Ícones no nome da janela (working/waiting/done) alimentados por hooks | **Stack** (estado estruturado e consultável) |
| **Heurística de "interrompido"** | ❌ (varredura de *stale* de 30 s no `acpd`) | ✅ **sem saída de pane por 10 s ⇒ interrompido** | **workmux** |
| **Auto-clear ao focar** | ❌ | ✅ `waiting`/`done` somem ao focar a janela | **workmux** |
| **Cromia semântica** | ✅ `permission` (laranja) ≠ `error` (vermelho), glifo + cor | Emoji configurável por estado | **Stack** (dupla codificação) |
| **Alertas sonoros** | ✅ sons por estado + debounce 650 ms; sino por breakpoint só como script | não declarado | **Stack** |
| **Chrome persistente** | **0 colunas** (popups efêmeros, eixo Z) | `sidebar` **opcional** + `dashboard` TUI | Depende da doutrina (Stack = zero chrome; workmux = mais descobrível) |
| **Revisão de mudanças** | **`lazygitrs`**: dual-diff `Ctrl+G` (Files ↔ HEAD), fila por risco, badge de testes, **nota inline → pane do agente** | `dashboard` com "revisar mudanças" e envio de comandos | **Stack** (loop de revisão dedicado) — *grau B para o lado do workmux: não vi o dashboard funcionando* |
| **Sandbox de agentes** | ❌ (`ai-jail` apenas documentado) | ✅ **container ou VM (Lima)** | **workmux** |
| **Nome de branch por LLM** | ❌ | ✅ | **workmux** |
| **Backends de terminal** | tmux | tmux, **WezTerm, kitty, Zellij** | **workmux** |
| **Instalação / portabilidade** | Dotfiles + Stow, só Linux, 7 pacotes com conflito de Stow ([N5](#n5--7-pacotes-têm-conflito-de-stow-pré-existente)) | Brew, Cargo, mise, Nix, script; macOS e Linux | **workmux** (por larga margem) |
| **Maturidade / ecossistema** | 0 estrelas externas, 1 mantenedor, `acpd` com 11 testes | 2,8k★, MIT, cadência alta de releases (tag `v0.1.271`), depoimentos públicos no README | **workmux** |
| **Doutrina de teclado** | Home-row, sem Alt, `keyd`, CapsLock dual | tmux padrão, sem doutrina própria | **Stack** (se você valoriza isso) |
| **Controle programático** | JSON-RPC (`acpd`), `acpd-cli`; falta `agentState/wait` | CLI; `add --wait` **bloqueia até a janela fechar** (útil em scripts), mas não espera por *estado* do agente | Empate (nenhum espera por transição de estado; o `agentState/wait` proposto seria mais fino) |
| **Telemetria do operador** | `flow-log` (troca de contexto) | não declarado | **Stack** (embora ainda sem dados) |
| **Retomada pós-reboot** | ❌ (só layout, estilo resurrect) | ⚠️ ligado ao tmux | Empate (ambos fracos) |

### 4.2 O que isso significa na prática

**Onde esta stack realmente se diferencia do workmux (e vale defender):**

1. **O loop de revisão.** O workmux gerencia *onde o agente trabalha*; esta stack também gerencia *como você lê e julga o que ele fez* (dual-diff, nota → agente, fila por risco). É a única vantagem **estrutural** — e é justamente onde a literatura aponta o gargalo (tempo de compreensão/verificação por diff; [§4.3 da auditoria](../architecture/workflow-flow-state-audit.md#43-amdahls-law-for-flow-and-the-fan-out-correction)).
2. **Estado estruturado e doutrina de entrada.** Estado de agente consultável por RPC, cores distintas por urgência, zero chrome persistente, home-row sem Alt.

**Onde o workmux está objetivamente à frente (e dá para roubar sem violar Zero-Churn):**

1. **Heurística de "interrompido" em 10 s** — barata de implementar no `acpd` (hoje há só uma varredura de 30 s). *Impacto direto no tempo de detecção de agente travado.*
2. **Auto-clear de `waiting`/`done` ao focar** — remove um clique/gesto de limpeza de badge. Casa com a doutrina de reduzir carga.
3. **Sandbox (container/Lima)** — a lacuna de **segurança** mais séria: agentes rodam com o seu usuário. Hoje é só documentação.
4. **Portabilidade e instalação.** Não é "roubável" no sentido de feature; é o custo de ser dotfiles pessoal. Só importa se o projeto for aberto.

**O que o workmux tem e não vale copiar:** sidebar/dashboard persistentes (contradizem a doutrina de zero chrome; o cockpit em popup já cobre o caso sob demanda), múltiplos backends (o valor da stack depende de `display-popup -E` efêmero, que é específico do tmux), nome de branch por LLM (conveniência, não gargalo).

### 4.3 Veredito sobre migrar para o workmux

**Não migrar.** O workmux resolve bem a camada de **worktree + janela + status**, que é a camada mais "commodity" desta stack. O que o workmux **não** cobre (revisão com nota para o agente, popups de eixo Z, doutrina home-row, telemetria estruturada via `acpd`) é onde o ganho de fluxo desta stack se concentra. Migrar trocaria os ativos reais por maturidade que, para um único operador, é secundária.

**Mas:** vale **incorporar as 3 ideias** acima (interrompido em 10 s, auto-clear ao focar, sandbox) e **manter a compatibilidade de `.workmux.yaml`** — ela já existe e é um seguro barato contra o abandono futuro de qualquer um dos lados.

---

## 5. Placar revisado

### 5.1 Critério e pesos

10 = melhor da categoria **e** evidenciado/medido; 8 = melhor da categoria por design, evidência parcial; 6 = funciona para o dono, frágil fora; 4 = quebrado ou sem evidência. "Como instalado" desconta defeitos verificados **e** capacidades que existem só no repositório ([N1](#n1--a-mudança-do-ghostty-está-só-no-repositório)) ou sem produtor ([N3](#n3--o-badge-de-testes-está-dormente)). Pesos: ergonomia 15, latência 15, navegação 10, revisão 20, supervisão 15, semiótica 5, resiliência 10, medição 5, manutenção 5.

### 5.2 Justificativa por dimensão (julgamento, grau C)

| Dimensão | Instalado | Por quê |
| :--- | :---: | :--- |
| Biomecânica de entrada | **8,8** | `keyd` reconciliado (+). Menos: bind morto e chord de 4 modificadores **ainda no Ghostty vivo** ([N1](#n1--a-mudança-do-ghostty-está-só-no-repositório)); 15 linhas com `ALT` no Hyprland, incluindo `SUPER+SHIFT+ALT+<tecla>`. |
| Latência | **8,5** | Pré-check do popup sem `git status` (+). Menos: `wm -f` ainda ~4× mais lento que `fzf` em razão relativa; latência do primeiro frame **não medida**. |
| Navegação | **9,0** | Inalterada. |
| Revisão | **8,0** | Popup volta a funcionar com resolução por capacidade (+4,0 vs 05/10). Teto limitado: badge sem produtor, fila por risco só por caminho, e nada **mede** o tempo de revisão. Design 9,2 se N3 for fechado. |
| Supervisão | **8,2** | Cores distintas (+). Menos: sino por breakpoint não integrado, sem `agentState/wait`, sem reidratação, sem heurística de interrompido. Focus/Triage descartado por decisão — **não penalizado**. |
| Semiótica | **8,3** | Distinção `permission`/`error` por cor (+). Justificativa φ/foveal ainda sem suporte (não alterada). |
| Resiliência | **5,5** | Inalterada: sem retomada, estado em memória, só Linux, **N5**. |
| Medição | **5,5** | `drift-doctor` e `flow-log` existem (+); mas ~2 dias de dados e sem métrica de espera/revisão. |
| Manutenibilidade | **5,0** | Inalterada: `acpd` 11 testes; 3 projetos com 1 mantenedor. |

### 5.3 Comparativo qualitativo com os demais concorrentes

Sem nota numérica para concorrentes (não os executei). Dados da API do GitHub em 2026-10-08 (grau B); funcionalidades da auditoria de 05/10 salvo indicação.

| | **Esta stack** | **Herdr** | **workmux** | **Agent of Empires** | **Claude Squad** | **worktrunk** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stars / licença | 0 / mista | **42,9k** / Apache-2.0 | 2,8k / MIT | 3,3k / MIT² | 8,6k / AGPL-3.0 | 9,0k / não detectada |
| Issues abertas | n/a | 320 | 61 | 149 | 52 | 63 |
| Último push | hoje | 2026-10-07 | 2026-10-04 | hoje | **2026-08-20** | hoje |
| Release recente | — | v0.9.3 (29/09) | v0.1.271 (04/10) | — | — | — |
| Substrato | tmux | servidor + PTY próprios | tmux (+WezTerm/kitty/Zellij) | tmux | tmux | git (CLI de worktree) |
| Estado do agente | **hooks → `acpd`** | manifestos de detecção + integrações por agente | hooks → ícones; interrompido em 10 s | monitor de estado | por tela | — |
| Loop de revisão | **✅ dual-diff + nota → agente** | não declarado | dashboard | diffs web | diff | — |
| Remoto / celular | Tailscale+SSH manual | **✅ máquinas SSH + cliente mobile** | via tmux/SSH | **✅ dashboard web (mobile)** | ❌ | — |
| Sandbox | docs (`ai-jail`) | não declarado | **✅ container / Lima** | **✅ Docker** | ❌ | — |
| Sobrevive a reboot | ⚠️ só layout | **✅ layout + retomada de agentes** | ⚠️ | ⚠️ | ⚠️ | n/a |
| Chrome persistente | **0** | sidebar | sidebar opcional | TUI cheia | TUI | — |
| Doutrina de teclado | **home-row / sem Alt** | prefixo + mouse | tmux padrão | teclas de TUI | teclas de TUI | n/a |

² O repositório mudou de `njbrake/agent-of-empires` para a organização `agent-of-empires/agent-of-empires` (redirecionamento 301 observado hoje); a auditoria anterior apontava o endereço antigo.

**Leitura:**

- **Herdr** continua sendo o concorrente com tração real (42,9k★) e o único com **sobrevivência a reboot, multi-máquina e API nativa de "esperar até bloquear"**. As três ideias a copiar não mudaram: primitiva `wait`, retomada pós-reboot, lista multi-host. **Não migrar** pelos mesmos motivos.
- **Claude Squad** está **parado há ~7 semanas** (último push em 20/08) apesar das 8,6k estrelas, com licença AGPL-3.0: sinal de que estrelas não implicam manutenção ativa.
- **worktrunk** (9,0k★) segue ativo; a licença não é detectada pela API (**C** — pode ser um arquivo customizado; verificar antes de depender).
- **Agent of Empires** é o irmão filosófico mais próximo (camada fina em Rust sobre tmux) e tem **dashboard web usável no celular** — a ideia de "aprovar permissão pelo telefone" continua sendo a única que esta stack não cobre e que o Herdr/AoE cobrem.
- **Age of Agents** e GUIs "ADE" (Orca, Conductor, Emdash, Superset) **não foram reavaliados**; as conclusões de 05/10 permanecem (visualizador somente-leitura é negativo para flow focado; ADEs são presas à janela do app).

### 5.4 Gerenciadores de arquivos e TUIs de Git (atualização curta)

| | Atualização 2026-10-08 |
| :--- | :--- |
| **Yazi** | 42,7k★, MIT, 70 issues, push em 05/10. Continua vencendo como **gerenciador de arquivos**. |
| **lazygit** | **83,0k★**, MIT, **1.050 issues abertas**, push hoje. Mindshare inalcançável; o fork `lazygitrs` segue valendo pelo loop de revisão. |
| **`lazygitrs` (fecavmi)** | 171 testes passando (era 168); 1 commit à frente do remoto (`dc5925b69`, ainda **não publicado**). |
| **`wm`** | Veredito de 05/10 mantido: ganha como *picker integrado ao ZLE/tmux*, perde como gerenciador de arquivos. Congelar `fm.rs` continua dependendo de dados que ainda não existem. |

---

## 6. O que falta (priorizado)

Mudança de estado desde 05/10: **todo o P0 está fechado**, exceto os ajustes de instalação dos achados novos.

### P0 — Minutos (instalação e honestidade do estado)

| Tarefa | Feito quando |
| :--- | :--- |
| Resolver **N1**: decidir a fonte (`Propo` ou não) e adotar o `ghostty/config` no Stow | `readlink ~/.config/ghostty/config` aponta para o repo; sem `alt+shift+enter` |
| Adicionar ao `drift-doctor` uma checagem de **conflito de Stow** (**N5**) | `./stow.sh -n` sem erros ou erros explicitamente tolerados |
| Publicar os commits pendentes (`acpd`: 1; `lazygitrs`: 1; dotfiles: 6+) | `git status` sem *ahead* |

### P1 — Dias

| Tarefa | Por que agora |
| :--- | :--- |
| `acpd`: **reidratar estado** a partir de `@ai_agent_state_*` **antes** de reiniciar o serviço ([N2](#n2--acpd-em-execução-ainda-é-o-binário-antigo)) | Reiniciar hoje zera os badges |
| `acpd`: heurística de **interrompido em 10 s** e **auto-clear ao focar** (ideias do workmux) | Menor esforço, maior ganho visível em supervisão |
| `acpd`: `agentState/wait` (long-poll) | Permite orquestração entre agentes/scripts; paridade com Herdr/workmux |
| **Produtor do badge de testes** ([N3](#n3--o-badge-de-testes-está-dormente)): hook/`awt` grava `Test-Status:` com o resultado **real** | Sem isto a alavanca 2 é só capacidade |
| Integrar `chime-at-breakpoint` ao `acpd` (sem modo Triage) | Script já existe; falta ligar à política de som |
| Registrar **espera `waiting → resposta`** e **tempo de revisão** na telemetria | Hoje nenhuma métrica responde "o fluxo melhorou?" |
| Perfilar o filtro headless do `wm` (F5) ou rotear `>5k` itens para `fzf --filter` | Razão relativa 4× continua |
| Ligar `drift-doctor` ao login | Fecha o critério "doctor sai 0 em todo login" |

### P2 — Semanas

| Tarefa | Observação |
| :--- | :--- |
| **Sandbox** no `awt` (bwrap/container/Lima) | Lacuna de segurança #1 frente ao workmux e AoE |
| **Retomada de agentes pós-reboot** (`sessions.json`) | Paridade com Herdr |
| Higienizar `ALT` do Hyprland (15 linhas) após período de não uso | Só depois da telemetria de uso |
| Licenças de `waymaker`/`acpd` (F8) e rebase/upstream do `lazygitrs` | Pré-requisito para abrir o código |
| `acpd`: subir a cobertura (11 testes / 5,4k LOC) | Hub de carga crítica com a menor cobertura |
| Avaliar refinar `review_priority` (churn × centralidade × sem teste; exceção por repositório) | Só se o uso real indicar necessidade ([N4](#n4--a-ordenação-por-risco-é-uma-heurística-de-caminho-e-muda-a-ordem-da-lista)) |

### P3 — Pesquisa

Lista multi-host sobre Tailscale e endpoint de aprovação no celular (AoE/Herdr); diff estrutural (`difftastic`); benchmark público reprodutível com harness de primeiro frame.

### Decisões registradas

| Decisão | Origem |
| :--- | :--- |
| Modo **Triage** e chave Focus/Triage **não serão implementados** — o cockpit cumpre a função | Dono, 2026-10-08 |
| Alterações no `lazygitrs` são feitas na worktree `fecavmi` | Dono, 2026-10-08 |
| `acpd --version` resolvido com *fast-path* manual, **sem `clap`** | Implementação, 2026-10-08 |

---

## 7. Ameaças à validade

1. **Uma máquina, uma rodada, carga diferente** — o piso de spawn mudou 4× entre as rodadas; só razões intra-rodada são utilizáveis.
2. **Nota de design vs. instalado é julgamento** — pesos herdados da auditoria anterior; trocar os pesos muda o total.
3. **O ganho de +1,0 é correção de defeito, não melhoria de fluxo.** Nenhum dado mede tempo de espera, tempo de revisão ou janela ininterrupta ainda.
4. **Competidores não foram executados**; o dashboard do workmux, as integrações do Herdr e o dashboard web do AoE estão em **grau B**.
5. **Viés de autor**: esta reavaliação foi feita por quem acabou de implementar as correções avaliadas. As colunas "Instalado" descontam o que não está aplicado ao sistema vivo justamente para mitigar isso, mas a verificação independente (outro revisor, ou ABAB de 4 semanas) continua necessária.

---

## 8. Fontes

- Auditoria canônica: [`workflow-flow-state-audit.md`](../architecture/workflow-flow-state-audit.md) · Plano: [`flow-state-implementation-plan.md`](../architecture/flow-state-implementation-plan.md) · Comparativo anterior: [`workflow-vs-herdr-comparison.md`](workflow-vs-herdr-comparison.md).
- workmux — <https://github.com/raine/workmux> (README lido em 2026-10-08), <https://workmux.raine.dev/>.
- API pública do GitHub (stars, licença, issues, último push, última release), consultada em 2026-10-08: `raine/workmux`, `herdrdev/herdr`, `agent-of-empires/agent-of-empires`, `smtg-ai/claude-squad`, `max-sixty/worktrunk`, `sxyazi/yazi`, `jesseduffield/lazygit`.
- Medições locais: reexecução do harness da §9.3 da auditoria; `./scripts/drift-doctor.sh`; `./stow.sh -n`; `cargo test` no `lazygitrs`; contagem de testes no `acpd`.
