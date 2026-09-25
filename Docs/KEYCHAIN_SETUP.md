# Configuração da chave dentro do app

Na primeira abertura, o app mostra uma tela `SecureField` para o usuário informar a chave da Groq. A chave é salva com `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` no Keychain do iPhone.

A chave não é:

- compilada no aplicativo;
- incluída no ZIP;
- gravada em `Info.plist`;
- enviada ao GitHub;
- escrita em logs;
- retornada pela interface.

O usuário pode alterar ou remover a chave em **Configurações → Alterar chave da IA**. A integração de visão deve construir `GroqVisionService.Configuration` somente depois de ler `KeychainStore.shared.readGroqKey()` em memória.

Para um app de produção distribuído publicamente, o desenho ainda mais seguro é usar um proxy backend próprio, porque qualquer chave Groq colocada em um app cliente pode ser extraída por engenharia reversa. O Keychain protege o armazenamento local, mas não transforma uma chave de cliente em segredo absoluto.
