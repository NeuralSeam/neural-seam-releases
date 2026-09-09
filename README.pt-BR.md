# Neural Seam Client Runtime (guia rápido)

Guia curto em português. A documentação canônica é o [README em inglês](./README.md) e o
[manual do usuário](./USER-MANUAL.md), que é onde tudo está detalhado e onde as correções entram
primeiro. Esta página cobre o suficiente para instalar, verificar e começar.

## O que é

O `neural-seam` é o binário que roda na sua máquina e liga o seu projeto local ao Neural Seam. Ele
**não roda inferência própria**: é um servidor MCP que expõe ferramentas ao seu host de agente, mais
uma ponte HTTP em loopback usada durante a configuração do projeto.

Toda chamada ao modelo parte de uma ação sua, no seu próprio host de agente. O binário nunca autentica
em provedor de modelo e não guarda credencial de provedor de modelo.

## Requisitos

- Windows 10 ou 11, x64. O piloto publica **windows/amd64**; em outra plataforma os scripts de
  instalação falham com mensagem clara em vez de baixar algo que não roda. Linux e macOS estão
  planejados.
- Uma conta Neural Seam.
- Um host de agente com suporte a MCP.
- HTTPS de saída para o backend do Neural Seam e para o GitHub.

## Instalar

**Usuário final no Windows.** Baixe o `neural-seam-installer-windows-amd64-setup.exe` da
[última release](https://github.com/NeuralSeam/neural-seam-releases/releases/latest) e execute. Ele
instala a CLI, configura o ícone de bandeja e a inicialização automática, e conduz o onboarding
(login, conexão do projeto, language servers).

Na primeira execução o Windows vai avisar sobre editor desconhecido. Isso é esperado hoje, e o
[SECURITY.md](./SECURITY.md) explica exatamente o que esse aviso diz e o que ele não diz.

**Desenvolvedor, CI ou headless.** Só a CLI, sem bandeja nem integração de desktop:

    irm https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.ps1 | iex

No Linux e no macOS:

    curl -fsSL https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.sh | sh

O script detecta a plataforma, baixa o artefato da release, **confere o SHA-256 contra o
`checksums.txt` e aborta se não bater**, e coloca o `neural-seam` num diretório do seu `PATH`.

## Primeiros passos

```sh
neural-seam version          # confirma a instalação
neural-seam setup            # login, language servers e conexão do diretório atual
neural-seam doctor           # diagnostica o que não subiu
```

Rode o `setup` de dentro do diretório do seu projeto. Depois abra o seu host de agente nesse mesmo
diretório. O resto está no [manual](./USER-MANUAL.md).

## Atualizar

    neural-seam upgrade

Atualização iniciada por você. Não há serviço em segundo plano nem agendamento: nada se atualiza
sozinho.

## Verificar a integridade

Todo caminho de instalação confere o SHA-256 contra o `checksums.txt` da release. À mão:

```powershell
Get-FileHash .\neural-seam-windows-amd64.exe -Algorithm SHA256
```

**Ainda não há assinatura de publicador.** Até que haja, a garantia é a conferência de SHA-256 mais o
HTTPS do GitHub, e o [SECURITY.md](./SECURITY.md) diz com todas as letras o que isso cobre e o que
não cobre.

## Desinstalar

1. Remova o binário de onde ele foi instalado (no Windows com instalador gráfico, use a desinstalação
   normal do sistema).
2. Opcionalmente apague `~/.neural-seam/`, que guarda credenciais, o registro local de projetos e os
   language servers provisionados.
3. Opcionalmente remova as entradas gerenciadas que o runtime adicionou aos seus projetos.

## Privacidade, segurança e suporte

- [PRIVACY.md](./PRIVACY.md): o que é enviado, quando, e o que nunca sai da sua máquina. Telemetria é
  opt-in e vem desligada.
- [SECURITY.md](./SECURITY.md): como reportar vulnerabilidade, e o relato honesto da cadeia de
  integridade.
- [SUPPORT.md](./SUPPORT.md): para onde vai cada tipo de pergunta.

Dúvida sobre conta, plano, projeto ou dados: <https://app.neuralseam.cloud>.

## Licença

O Neural Seam Client Runtime é **software proprietário**, não open source. Veja
[LICENSE.md](./LICENSE.md) para o que você pode e não pode fazer com os binários publicados aqui, e
[THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) para os componentes open source embutidos, cada um
sob a própria licença.

Os plugins do Neural Seam para hosts de agente são projetos separados e são MIT. A licença deles não
se estende a este software.
