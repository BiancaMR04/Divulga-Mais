# Ferramentas Admin (Firebase)

Este diretório contém um script para cadastrar/promover um usuário como `superuser` no Firestore usando **Firebase Admin SDK** (ignora regras do Firestore).

## 1) Criar chave de Service Account

Firebase Console → **Project settings** → **Service accounts** → **Generate new private key**.

Baixe o JSON e **não commite** (já está no `.gitignore`).

## 2) Instalar dependências

No Windows (PowerShell), na raiz do projeto:

```powershell
cd tools\firebase-admin
npm install
```

## 3) Rodar o script

### Promover usuário existente (por email)

```powershell
cd tools\firebase-admin
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\caminho\\service-account.json"
node .\promote-superuser.mjs --email "seuemail@dominio.com"
```

### Promover por UID

```powershell
cd tools\firebase-admin
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\caminho\\service-account.json"
node .\promote-superuser.mjs --uid "UID_DO_USUARIO"
```

### (Opcional) Criar Auth user + promover

```powershell
cd tools\firebase-admin
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\caminho\\service-account.json"
node .\promote-superuser.mjs --createAuth --email "admin@dominio.com" --password "SenhaForte123!" --nome "Admin"
```

## O que o script grava

Em `usuarios/{uid}`:
- `tipo: "superuser"`
- `ativo: true`
- `criadoEm` (se não existir)
- `atualizadoEm`
- `email`/`nome` (se você passar via parâmetro)
