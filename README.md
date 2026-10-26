# Barbearia Grau e Corte — site + agendamento + Pix + painel

O frontend é hospedado no GitHub Pages; o backend, banco e funções seguras rodam no Supabase. O pagamento automático usa Mercado Pago Pix. **Não é possível ter agendamento real, bloqueio concorrente e confirmação automática de Pix usando apenas HTML estático no GitHub Pages.** Este projeto inclui a estrutura e o código do backend, mas você precisa criar suas contas e inserir as chaves secretas.

## O que vem no pacote
- `index.html`: site responsivo, tema escuro/claro, serviços, formulário, disponibilidade consultada no banco, Pix copia-e-cola/QR e encaminhamento ao WhatsApp.
- `admin.html`: painel administrativo com login, listagem de reservas e ações de confirmar/cancelar/concluir.
- `supabase/schema.sql`: tabelas, RLS, prevenção de horários sobrepostos e funções de disponibilidade/reserva.
- `supabase/functions/create-pix-payment`: cria cobrança Pix no Mercado Pago.
- `supabase/functions/mercadopago-webhook`: verifica a cobrança consultando a API do Mercado Pago e confirma reservas após pagamento aprovado.
- `supabase/functions/admin-update-booking`: atualiza status de reserva para usuários admin.

## 1. Criar o Supabase
1. Crie um projeto em https://supabase.com/.
2. Em **SQL Editor**, execute todo o arquivo `supabase/schema.sql`.
3. Em **Project Settings → API**, copie Project URL e `anon`/publishable key.
4. Edite `index.html` e `admin.html`: substitua `COLE_A_URL_DO_SUPABASE` e `COLE_A_CHAVE_ANON_DO_SUPABASE`.
5. Nunca coloque `service_role` ou token do Mercado Pago em HTML, repositório ou GitHub Actions.

## 2. Criar usuário administrador
1. No Supabase, abra **Authentication → Users → Add user** e crie seu usuário com e-mail e senha.
2. Copie o UUID desse usuário.
3. No SQL Editor, execute:
   `insert into public.admin_users(user_id) values ('COLE-O-UUID-AQUI');`
4. Publique `admin.html`; abra `https://SEU-USUARIO.github.io/SEU-REPOSITORIO/admin.html` e entre.

## 3. Configurar Mercado Pago Pix
1. Crie/acesse uma conta de vendedor e credenciais de aplicação no https://www.mercadopago.com.br/developers.
2. Use primeiro as credenciais de teste. Para cobrança real, use credenciais de produção e faça testes de ponta a ponta.
3. Instale o Supabase CLI e faça login. Na raiz do projeto:
   `supabase login`
   `supabase link --project-ref SEU_PROJECT_REF`
4. Configure os secrets (nunca os comite):
   `supabase secrets set MERCADOPAGO_ACCESS_TOKEN=SEU_ACCESS_TOKEN PUBLIC_SITE_URL=https://SEU-USUARIO.github.io/SEU-REPOSITORIO`
5. Publique as funções:
   `supabase functions deploy create-pix-payment`
   `supabase functions deploy mercadopago-webhook`
   `supabase functions deploy admin-update-booking`
6. Em Mercado Pago, configure notificações de pagamento para a URL:
   `https://SEU_PROJECT_REF.supabase.co/functions/v1/mercadopago-webhook`
   A função também envia essa URL ao criar o pagamento. Confirme que o webhook está ativo e teste notificações em ambiente de teste.
7. Se a conta do Mercado Pago exigir e-mail válido do pagador, peça o e-mail no formulário; o campo é opcional no protótipo e usa fallback, que você pode tornar obrigatório em produção.

## 4. Publicar no GitHub Pages
1. Crie um repositório e envie `index.html`, `admin.html` e a pasta `supabase` (para versionar os fontes; as funções são implantadas pelo CLI).
2. No GitHub, abra **Settings → Pages → Deploy from a branch → main → /(root)**.
3. A URL pública será `https://SEU-USUARIO.github.io/SEU-REPOSITORIO/`.

## 5. Horários, expediente e manutenção
- Horário padrão: 09:00–20:00; slots a cada 30 minutos. Altere a função `available_slots` em `schema.sql` para o expediente real.
- A função `expire_stale_bookings()` expira reservas pendentes antigas. Configure uma execução agendada no Supabase (Cron) a cada 5 minutos, se disponível no seu plano, para liberar slots de pagamentos abandonados. Sem isso, reservas pendentes continuam bloqueando o horário até serem expiradas.
- A constraint no banco impede duas reservas ativas sobrepostas. Mesmo se dois clientes clicarem ao mesmo tempo, apenas uma reserva para aquele intervalo será aceita.
- O painel lista agendamentos; o barbeiro pode confirmar, cancelar e marcar como concluído.
- O endereço configurado é `Travessa Bernadino de Campos, 17`.
- WhatsApp configurado como `+55 11 94820-7983`; Pix informado como `1194820-7983`. Confirme os números antes de divulgar.

## Limitações e avisos antes de produção
- A chave Pix manual `1194820-7983` não permite confirmação automática por si só. Para confirmação automática, o código gera uma cobrança Pix por transação via Mercado Pago. O valor é pago para a conta Mercado Pago vinculada às credenciais, que precisa estar configurada corretamente; não é automaticamente encaminhado à chave Pix informada.
- Se você deseja receber diretamente na chave Pix do telefone, confirme com o banco se há API de cobrança Pix integrada e use a API oficial do banco em vez do Mercado Pago.
- Webhook consulta a API do Mercado Pago antes de marcar pagamento aprovado. Faça testes em sandbox e produção; revise validação de assinatura do webhook e regras antifraude antes de escala comercial.
- O arquivo HTML usa a chave pública/anon do Supabase, que pode ficar no frontend se as políticas RLS estiverem corretas. Nunca exponha a service role key.
- A duração do serviço controla bloqueio de sobreposição. Horário de funcionamento, feriados, folgas e intervalo de almoço precisam ser ajustados para sua operação.
