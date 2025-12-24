# Manual de Testes do Cliente — Divulga Pampa (Google Play)

Este manual é para **o cliente** validar as funcionalidades do app após instalar pela **Google Play**.

> Observação: este guia não exige computador/Flutter. Para testes técnicos (rodar em debug, logs, etc.), use [GUIA_TESTES.md](GUIA_TESTES.md).

---

## 1) Objetivo

- Validar que o app instala, abre e navega corretamente.
- Validar leitura de conteúdo (menus, submenus e artigos) e recursos (busca, filtros, vídeos, links).
- Validar fluxo de conta (criar conta, login, recuperação de senha, perfil e logout).
- Se aplicável: validar perfis **Líder** e **Superuser** (aba “Gerenciar”).

---

## 2) Pré‑requisitos (antes de começar)

- Celular Android com internet (Wi‑Fi/4G).
- Ter um e‑mail que você consiga acessar (para teste de “Esqueceu sua senha?”).
- Recomendado: ter acesso a **2 contas** (fornecidas pela equipe):
  - Conta **Líder** (tipo `lider`) — para criar/editar publicações e editar “Meu PPG / Grupo”.
  - Conta **Superuser** (tipo `superuser`) — para gerenciar usuários/menus e moderar publicações.

Se você **não tiver** contas de líder/superuser, faça somente os testes de “Usuário comum”.

---

## 3) Instalação (Google Play)

1. Abra a **Google Play Store**.
2. Encontre o app (link direto ou busca pelo nome informado pela equipe).
3. Toque em **Instalar**.
4. Abra o app.

**Resultado esperado:** o app abre sem travar e mostra a tela inicial com título “Divulga Pampa”, campo de busca e cards de menu.

---

## 4) Checklist rápido (Smoke Test — 3 a 5 minutos)

- [ ] App abre sem travar
- [ ] Tela inicial (“Início”) carrega com menus
- [ ] Barra de busca aceita texto
- [ ] Botão de filtro (ícone de funil) abre o filtro por ano
- [ ] Abrir um menu e voltar funciona
- [ ] Abrir um artigo e voltar funciona
- [ ] Abrir tela de Login e voltar funciona

Se qualquer item acima falhar, já vale reportar (ver seção **10) Como reportar problemas**).

---

## 5) Navegação e Menus (Usuário comum)

### 5.1) Menus principais (Início)

1. Na aba **Início**, toque em 2 menus diferentes.
2. Em cada tela, use o **voltar** e confirme que retorna para a tela anterior.

**Resultado esperado:**
- Menus abrem e voltam sem travar.
- O conteúdo carrega (mesmo que demore alguns segundos em internet lenta).

### 5.2) Submenus (quando o menu abre uma “grade”)

1. Entre em um menu que leve para uma lista/grade de submenus.
2. Abra pelo menos 2 submenus.

**Resultado esperado:**
- O título da tela muda conforme o submenu.
- Se houver sub-submenus, abre outra grade.

---

## 6) Busca e Filtro por Ano

### 6.1) Busca (na Home e em submenus)

1. Na Home, digite um termo no campo **“Pesquise postagens…”**.
2. Verifique se aparecem resultados de artigos.
3. Teste com:
   - uma palavra curta (ex.: “saúde”)
   - uma palavra com acento e sem acento (ex.: “pós” e “pos”)

**Resultado esperado:**
- A lista de artigos é filtrada conforme o texto.
- Termos com/sem acento encontram conteúdos equivalentes quando existirem.

### 6.2) Filtro por ano (Home)

1. Toque no ícone de filtro.
2. Marque **“Mostrar apenas artigos do último ano”**.
3. Toque em **Aplicar**.
4. Depois volte no filtro e toque em **Limpar**.

**Resultado esperado:**
- Ao aplicar, a lista muda (pode reduzir).
- Ao limpar, volta ao estado anterior.

### 6.3) Filtro por ano (Submenus e listagem de artigos)

1. Dentro de um submenu/lista de artigos, toque no filtro.
2. Selecione **Ano inicial** e/ou **Ano final**.
3. Toque em **Aplicar**.

**Resultado esperado:**
- Resultados se ajustam ao intervalo selecionado.

---

## 7) Artigos (Listagem e Detalhe)

### 7.1) Listagem de artigos

1. Abra um menu/submenu do tipo “Artigos” (ou use a busca para listar artigos).
2. Role a lista e abra 3 artigos diferentes.

**Resultado esperado:**
- Cada item mostra pelo menos título e informações básicas.
- Abrir/voltar funciona.

### 7.2) Tela de detalhe

Em cada artigo aberto, validar:

- [ ] Título aparece (no topo e/ou no conteúdo)
- [ ] Autor aparece
- [ ] Data de publicação aparece (quando existir)
- [ ] Texto/resumo/conteúdo permite rolar (scroll)

**Imagens:**
- Se o artigo tiver imagem, ela carrega e aparece com boa qualidade.

**Vídeos (quando existir):**
1. Toque no botão de **play**.
2. Pause e retome.
3. Arraste a barra de progresso (scrub).

**Resultado esperado:**
- Vídeo inicia, pausa e continua.
- Barra de progresso responde.

---

## 8) Telas institucionais e Contatos

### 8.1) Tela “Quem somos” / “Informações” / “Texto”

1. Abra um menu que leve para “Quem somos” ou uma tela de texto.
2. Verifique:
   - título
   - imagem (se existir)
   - texto com scroll

**Resultado esperado:** carrega e o texto é legível.

### 8.2) Contatos (telefone, e-mail e redes)

1. Abra um menu/submenu do tipo **Contatos**.
2. Toque em um telefone.
3. Volte para o app.
4. Toque em um e‑mail.
5. Toque em um link de rede social.

**Resultado esperado:**
- Telefone abre o discador.
- E‑mail abre o app de e‑mail.
- Redes/links abrem no navegador/app externo.

---

## 9) Conta do usuário: Cadastro, Login, Perfil e Logout

### 9.1) Criar conta

1. Na barra inferior, toque em **Login**.
2. Toque em **Criar nova conta**.
3. Preencha:
   - Nome
   - E‑mail
   - Tipo de usuário (Discente/Docente/TAE/Outros)
   - Senha e confirmação
4. Toque em **Cadastrar**.

**Resultado esperado:**
- Conta é criada e o app volta para o fluxo principal.

### 9.2) Login

1. Saia da conta (se necessário) e tente entrar novamente.
2. Preencha e‑mail e senha.
3. Toque em **Entrar**.

**Resultado esperado:**
- Login completa e aparece uma mensagem de boas‑vindas.

### 9.3) “Esqueceu sua senha?”

1. Na tela de Login, preencha o e‑mail.
2. Toque em **Esqueceu sua senha?**

**Resultado esperado:**
- App informa que o link foi enviado.
- Chega um e‑mail de redefinição (verificar caixa de spam, se necessário).

### 9.4) Perfil e logout

1. Na barra inferior, toque em **Perfil**.
2. Confira nome, e‑mail e tipo.
3. Toque em **Sair da conta**.

**Resultado esperado:**
- Usuário é deslogado.
- A barra inferior volta a mostrar **Login** no lugar de Perfil.

---

## 10) “Gerenciar” (somente para contas Líder e Superuser)

> Se você não tiver a conta com permissão, pule esta seção.

### 10.1) Conta Líder — Publicações

1. Faça login com a conta **líder**.
2. Na barra inferior, deve aparecer a aba **Gerenciar**.
3. Entre em **Gerenciar → Publicações**.

**Criar uma nova publicação**
1. Toque no botão **+**.
2. Preencha os obrigatórios:
   - Título
   - Resumo
   - Conteúdo
   - Área
   - Classificação (ex.: “Geral” ou “Editais e notícias”)
3. (Opcional) Adicione:
   - Linhas de pesquisa (selecionar e tocar em “Adicionar linha”)
   - Tags (separadas por vírgula)
   - Imagem (URL)
   - Link (URL)
   - Vídeo (URL)
4. Toque em **Salvar**.

**Resultado esperado:**
- App mostra “Publicação salva”.
- A publicação aparece na lista.

**Editar / Ativar / Desativar / Excluir**
- Abra uma publicação existente e altere algum campo; salve.
- Use o menu (⋮) para **Ativar/Desativar**.
- Exclua uma publicação de teste.

**Resultado esperado:**
- Alterações ficam persistidas.
- Ativar/Desativar muda o status.
- Excluir remove a publicação.

**Verificar no app (lado do usuário)**
- Volte para **Início** e confirme que a publicação aparece (quando estiver ativa), via busca ou navegando pelos menus.

### 10.2) Conta Líder — Meu PPG / Grupo

1. Vá em **Gerenciar → Meu PPG / Grupo**.
2. Procure opções de edição (ex.: sobre, integrantes, contatos, linhas de pesquisa).
3. Faça uma alteração pequena (ex.: adicionar uma frase no texto) e salve.

**Resultado esperado:**
- Alteração aparece nas telas públicas correspondentes (ao navegar pelos menus/submenus).

### 10.3) Conta Superuser — Moderação de publicações

1. Faça login com a conta **superuser**.
2. Vá em **Gerenciar → Publicações**.
3. Teste:
   - buscar por título/autor
   - aprovar/publicar ou despublicar (toggle)
   - editar campos
   - excluir

**Resultado esperado:**
- Ações funcionam e refletem no app para usuários.

### 10.4) Conta Superuser — Usuários

1. Vá em **Gerenciar → Usuários**.
2. Teste:
   - buscar por nome/email/UID
   - ativar/desativar
   - alterar papel (comum/líder/superuser)
   - (se disponível) definir/editar escopo do líder

**Resultado esperado:**
- Mudanças persistem e alteram o acesso às abas (ex.: líder/superuser passam a ver “Gerenciar”).

### 10.5) Conta Superuser — Menus

1. Vá em **Gerenciar → Menus**.
2. Se permitido pela equipe, crie/edite um menu de teste ou reordene.

**Resultado esperado:**
- Mudanças aparecem na Home (menus ativos e ordenados).

---

## 11) Como reportar problemas (modelo)

Quando encontrar um problema, envie (WhatsApp/e‑mail/planilha, como combinado) com:

- **Título:** (ex.: “Vídeo não carrega no detalhe do artigo X”)
- **Data e hora do teste**
- **Celular / Android:** modelo e versão (ex.: “Moto G9 — Android 12”)
- **Conexão:** Wi‑Fi/4G e se estava instável
- **Conta usada:** comum / líder / superuser (não precisa informar senha)
- **Passos para reproduzir:** 1…2…3…
- **Resultado esperado** x **resultado atual**
- **Evidência:** print ou vídeo de tela

Modelo pronto:

```text
Título:
Data/hora:
Aparelho/Android:
Conexão:
Conta (comum/líder/superuser):
Passos:
1)
2)
3)
Esperado:
Atual:
Evidências (prints/vídeo):
```
