# Nutria

Assistente nutricional com IA — bate-papo com streaming, despensa inteligente, sugestão de receitas e perfil com foto. Aplicação **Elixir/Phoenix** (umbrella).

## Apps (umbrella)

| App | Descrição |
| --- | --- |
| `nutria` | Núcleo da aplicação: contas, autenticação, chat, conversas, LLM, despensa, receitas e uploads |
| `nutria_app` | Interface mobile-only (Phoenix LiveView) |

## Funcionalidades

- **Chat com IA em streaming**: mensagens palavra a palavra, com badge de "pensando" e fallback entre provedores
- **LLM multi-provedor**: roteamento rápido (`fast`) vs. inteligente (`smart`) com fallback automático — Google e Zen
- **Despensa (pantry)**: gerencie itens e gere receitas com os ingredientes disponíveis (com controle de uso)
- **Histórico de conversas**
- **Autenticação**: e-mail/senha (bcrypt), Google OAuth e JWT (`joken`) para a API
- **Perfil**: troca de foto com upload direto (blur + câmera no avatar, upload automático) e tema claro/escuro
- **UI mobile-only** com navegação por abas

## Stack

- Elixir ~> 1.18, Phoenix ~> 1.7, Phoenix LiveView ~> 1.0
- Ecto + Postgres (chaves `binary_id`), Tailwind CSS 4, Heroicons, `req`/`jason`, CORS (`cors_plug`)

## Configuração

Pré-requisitos: Elixir, PostgreSQL em execução local.

```bash
mix deps.get
mix ecto.setup   # cria e migra o banco
mix phx.server   # http://localhost:4000
```

O CSS é compilado automaticamente via Tailwind (watcher do `phx.server`).

## Aplicativo nativo (Capacitor)

O app roda dentro de um shell nativo via [Capacitor](https://capacitorjs.com/), servindo o LiveView existente (sem downgrade do Phoenix). O `web/` é um placeholder; o app real é carregado a partir do servidor via `server.url`.

```bash
npm install
npx cap add android   # uma vez
npx cap add ios       # uma vez (requer macOS/Xcode)
npx cap sync          # copia a config para as plataformas
npm run android       # abre no Android Studio
npm run ios           # abre no Xcode
```

Aponte o servidor Phoenix para o host do dispositivo/emulador na `capacitor.config.ts` (padrão: `http://10.0.2.2:4000`, o `localhost` do emulador Android). Use `CAPACITOR_SERVER_URL` para sobrescrever:

```bash
CAPACITOR_SERVER_URL=http://192.168.0.10:4000 npx cap sync
```

### Variáveis de ambiente

| Variável | Uso | Padrão |
| --- | --- | --- |
| `POSTGRES_DB` | Banco de dados | `nutria_dev` |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Credenciais do Postgres | usuário do sistema / vazio |
| `JWT_SECRET` | Assinatura de tokens JWT | valor de dev (exigida em produção) |
| `GOOGLE_AI_KEY` | Provedor Google (LLM) | — |
| `ZEN_API_KEY` | Provedor Zen (LLM) | — |
| `LLM_FAST_PROVIDER` / `LLM_FAST_MODEL` | Modelo rápido | `google` / `gemma-4-26b-a4b-it` |
| `LLM_SMART_PROVIDER` / `LLM_SMART_MODEL` | Modelo inteligente | `zen` / `deepseek-v4-flash-free` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google OAuth | credenciais de dev |
| `GOOGLE_REDIRECT_URI` | Callback do OAuth | `http://localhost:4000/auth/google/callback` |

## Testes

```bash
mix test
```

## Estrutura

```
apps/
  nutria/          # domínio (contas, chat, despensa, receitas, LLM, uploads)
  nutria_app/      # LiveView, controllers, layout e ativos do front único
config/            # config da umbrella
```

Rotas principais: `/` (chat), `/pantry`, `/history`, `/login` e `/api/*` (JSON).
