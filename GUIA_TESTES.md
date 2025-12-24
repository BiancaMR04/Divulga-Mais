# Guia de Testes (QA) — Divulga Pampa

> Objetivo: orientar testers a validar os fluxos principais do app.
> 
> **Observação:** imagens/screenhots podem ser adicionadas depois. Onde aparecer **(adicionar imagem aqui)**, você pode colar prints.

---

## 1) Pré-requisitos

- Flutter instalado e configurado (Android Studio/SDK, ou dispositivo físico).
- Acesso ao projeto Firebase configurado para este app.
- Um emulador Android ou um celular Android com depuração USB.

**(adicionar imagem aqui)**

---

## 2) Como executar o app

### Opção A — Rodar no emulador/dispositivo
1. Abra o projeto no VS Code.
2. Conecte um dispositivo ou inicie um emulador.
3. Execute:
   - `flutter pub get`
   - `flutter run`

### Opção B — Build de APK (para distribuir a testers)
- `flutter build apk --release`

**Onde encontrar:** `build/app/outputs/flutter-apk/app-release.apk`

**(adicionar imagem aqui)**

---

## 3) Checklist rápido (Smoke Test)

Use este checklist para validar rapidamente se o app está “de pé”.

- [ ] App abre sem travar
- [ ] Home carrega menus
- [ ] Busca (barra de pesquisa) aparece e aceita texto
- [ ] Abertura de um menu/submenu funciona
- [ ] Lista de artigos/postagens carrega
- [ ] Abrir detalhe de artigo funciona
- [ ] Login abre e permite entrar (se credenciais existirem)

---

## 4) Fluxos principais para testar

### 4.1) Navegação e UI (responsividade)
Testar em pelo menos 2 tamanhos:
- Celular pequeno (ex.: 360x640)
- Celular maior (ex.: 411x891)

Validar:
- [ ] Títulos não “quebram” layout
- [ ] Não aparece overflow (faixa amarela/preta)
- [ ] Conteúdo continua acessível com scroll
- [ ] Barra de pesquisa permanece na posição esperada

**(adicionar imagem aqui)**

---

### 4.2) Home (Menus)
- [ ] Grid de menus aparece
- [ ] Ao tocar em um menu de **submenu**, navega para submenus
- [ ] Ao tocar em um menu de **artigos**, abre listagem
- [ ] Ao tocar em **contatos/quemsomos/texto**, abre a tela correta

**(adicionar imagem aqui)**

---

### 4.3) Submenus
- [ ] Botão voltar retorna corretamente
- [ ] Título do topo se ajusta (não fica com `...`)
- [ ] Logo não invade o título em telas pequenas
- [ ] Barra de pesquisa funciona
- [ ] Filtro por ano abre, aplica e limpa

**(adicionar imagem aqui)**

---

### 4.4) Busca e filtros
#### Busca
- [ ] Digitar termo filtra resultados
- [ ] Termo com acento e sem acento encontra resultados (ex.: “pós” vs “pos”)
- [ ] Termos longos não travam UI

#### Filtro por ano
- [ ] Selecionar ano inicial
- [ ] Selecionar ano final
- [ ] Aplicar filtro reflete nos resultados
- [ ] Limpar filtro volta ao estado inicial

**(adicionar imagem aqui)**

---

### 4.5) Artigos
- [ ] Lista carrega sem erro
- [ ] Card mostra título/autor/resumo
- [ ] Abrir detalhe não trava
- [ ] Conteúdo longo no detalhe permite scroll

**(adicionar imagem aqui)**

---

### 4.6) Login e Cadastro
> Se o ambiente Firebase não permitir criar usuários (ou tiver regras), registrar isso no relatório.

#### Login
- [ ] Validação de e-mail/senha
- [ ] “Esqueceu sua senha?” envia e-mail quando há e-mail preenchido
- [ ] Login com credenciais válidas redireciona para Home

#### Cadastro
- [ ] Validação de campos obrigatórios
- [ ] Confirmação de senha
- [ ] Seleção de tipo de usuário
- [ ] Cadastro com dados válidos cria usuário e redireciona

**(adicionar imagem aqui)**

---

## 5) Perfis/Permissões (se aplicável)

Se existirem perfis diferentes (ex.: comum, líder, superuser), validar:
- [ ] O menu/ações exibidas mudam conforme o tipo
- [ ] Telas restritas bloqueiam acesso quando não autorizado

**(adicionar imagem aqui)**

---

## 6) Relato de bugs (padrão sugerido)

Ao abrir um bug, incluir:
- **Título:** curto e direto
- **Ambiente:** Android (modelo), versão do Android, build (debug/release)
- **Passos para reproduzir:** 1…2…3…
- **Resultado esperado** vs **resultado atual**
- **Evidência:** print/vídeo (**adicionar imagem aqui**)
- **Logs:** se possível, `flutter run`/Logcat

Modelo:

```
Título:
Ambiente:
Passos:
1)
2)
3)
Esperado:
Atual:
Evidências:
Logs:
```

---

## 7) Casos de teste adicionais (opcional)

- [ ] Modo avião / sem internet (mensagens e estados de loading)
- [ ] Rotação de tela (se suportado)
- [ ] Acessibilidade: fonte grande (Configurações do Android)
- [ ] Testar em aparelho com pouca memória

**(adicionar imagem aqui)**
