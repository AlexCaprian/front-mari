# Mari (BabyBox)

Aplicativo Flutter de gestão para pequenos negócios (voltado a lojas de produtos infantis): controle de vendas, transações financeiras, produtos/estoque (opcional) e relatórios mensais, com dashboard e sincronização com uma API própria.

## Funcionalidades

- **Autenticação** de conta, com sessão persistida localmente.
- **Dashboard** com resumo do mês (vendas, entradas/saídas).
- **Vendas**: lançamento e histórico.
- **Transações financeiras**: entradas e saídas, com filtro por período e tipo.
- **Produtos/estoque**: cadastro opcional — o fluxo funciona mesmo sem controle de estoque.
- **Relatórios**: relatório mensal e comparação entre meses.
- **Exportação** de dados (Excel/CSV).
- **Acessibilidade**: ajuste de tamanho de fonte do app.
- Interface adaptada para **mobile e desktop**.

## Stack

- [Flutter](https://flutter.dev/) / Dart
- [Provider](https://pub.dev/packages/provider) para gerência de estado
- [Dio](https://pub.dev/packages/dio) para comunicação com a API (com *certificate pinning*)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) para armazenar a sessão
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) para configuração de ambiente

## Configuração

O app depende de uma API própria (não incluída neste repositório). A URL dela não fica hardcoded no código — é lida de um arquivo `.env` local, que **não é versionado**.

1. Copie o template:

   ```bash
   cp .env.example .env
   ```

2. Edite `.env` e informe a URL da sua API:

   ```
   API_BASE_URL=https://seu-host/babybox
   ```

Se a API usar um certificado autoassinado, ajuste também o certificado pinado em `lib/services/http_client_config_io.dart`.

## Rodando o projeto

```bash
flutter pub get
flutter run
```

## Estrutura

```
lib/
  models/     # modelos de dados (conta, produto, venda, transação, relatórios)
  screens/    # telas (dashboard, vendas, transações, produtos, relatórios, desktop/)
  services/   # cliente HTTP, rotas da API, sincronização, armazenamento de token
  state/      # controllers (Provider/ChangeNotifier)
  theme/      # tema visual do app
  widgets/    # componentes reutilizáveis
  utils/      # utilitários
```

## Build

```bash
flutter build apk      # Android
flutter build ios      # iOS
flutter build windows  # Windows
flutter build web      # Web
```
