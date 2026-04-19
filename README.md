# AppCarol

App em SwiftUI para gestao de pacientes com login, sessao persistida, notificacoes locais, historico de alteracoes e visao gerencial com grafico.

## O que ja esta pronto

- Login e cadastro de usuario com persistencia local.
- Sessao persistida entre aberturas do app.
- Logout.
- Cadastro, edicao e resolucao de pacientes.
- Lista vertical com cards de pacientes.
- Notificacoes locais por paciente com identificadores unicos.
- Agrupamento de notificacoes usando `threadIdentifier = patient.id`.
- Cancelamento das notificacoes ao resolver o paciente.
- Historico completo com campo alterado, valor antigo, valor novo, data e usuario.
- Exclusao logica com regra de permissao: apenas quem criou pode excluir.
- Tela gerencial com filtros e grafico de pacientes por dia usando Swift Charts.

## Armazenamento

Esta primeira versao usa armazenamento local em JSON, salvo em:

`~/Library/Application Support/AppCarol/`

Arquivos persistidos:

- `database.json`
- `session.json`

## Estrutura alinhada ao Firestore

Mesmo com backend local, a modelagem ja foi preparada para refletir a estrutura abaixo:

- `patients/{patientId}`
- `patients/{patientId}/history/{historyId}`

Na pratica, isso facilita trocar a camada local por Firestore depois sem refazer a UI nem as regras de negocio.

## Como validar no Mac

1. Abra a pasta do repositorio no Xcode pelo arquivo `Package.swift`.
2. Rode o target `AppCarol`.
3. Faca um cadastro de usuario.
4. Cadastre pacientes com diferentes quartos, setores e medicacoes.
5. Valide os alertas locais.
6. Edite um paciente e confira o historico.
7. Marque um paciente como resolvido e confirme que as notificacoes dele foram canceladas.
8. Abra a tela gerencial e teste os filtros e o grafico.

## Validacao por terminal

Compilacao ja validada com:

```bash
swift build
```

## Proximo passo sugerido

Se voce aprovar essa primeira versao, eu posso seguir com a etapa de publicacao no GitHub e, se voce quiser, tambem posso preparar a segunda etapa com integracao real em Firestore.
