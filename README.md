# iPad Espelho

Pequena app para macOS que mostra o ecrã de um iPad (ou iPhone) ligado por cabo numa janela do Mac. A ideia é partilhar essa janela em reuniões do Google Meet, Zoom ou Teams.

Usa o mesmo mecanismo do QuickTime («Nova gravação de filme» com o iPad como câmara): `AVFoundation` + `CoreMediaIO`, sem drivers nem software extra no iPad.

## Funcionalidades

- Deteta o iPad sozinha quando o ligas ou desligas.
- A janela segue a proporção do ecrã, também quando rodas o iPad.
- **Visualização:** Sempre no topo (⌘T), Tamanho real (⌘1), Ecrã inteiro (⌘F).
- **Dispositivo:** escolher entre vários dispositivos, Procurar de novo (⌘R).

## Compilar

Precisa do Xcode ou das Command Line Tools (macOS 14 ou superior).

```bash
./build.sh
open "iPad Espelho.app"
```

## Usar

1. Liga o iPad ao Mac por cabo, desbloqueia-o e toca em **«Confiar»** se te for pedido.
2. Abre a app e aceita o pedido de acesso à **Câmara** (é assim que o macOS trata o ecrã do iPad).
3. No Meet: **Apresentar → Uma janela** e escolhe «iPad Espelho».

## Limitações

- Só imagem, sem som.
- Só por cabo. Sem cabo, usa o «Duplicar ecrã» (AirPlay para o Mac) do próprio macOS.
