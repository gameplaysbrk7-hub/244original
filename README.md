# Moto Grau (nome provisório)

Jogo 3D de motos para Android feito em **Godot 4.3** (GDScript tipado, renderizador Compatibility),
inspirado na pilotagem com grau de jogos de motos brasileiros. Projeto original: sem assets de terceiros,
tudo é gerado proceduralmente.

> **Estado: Fase 4 (garagem, missões, dinheiro, salvamento) e gráficos melhorados, sobre as Fases 1 a 3.** Ainda **não foi testado em aparelho real nem compilado pelo autor deste
> código**: o primeiro build no GitHub Actions é o teste de verdade. Se algo falhar, abra o log da
> execução (artefato `build-logs`) e corrija a partir dele.

## O que já existe

### Ajustes recentes
- **Trânsito corrigido:** os carros agora circulam pelas ruas (mão direita, semáforos, curvas nos cruzamentos). A detecção de obstáculos passou a ser por geometria simples (sem consultas de física) e carros parados sem motivo por mais de 10 s são reposicionados
- **Entregas:** o pedido é retirado numa das 3 **HAMBURGUERIAS** (prédio com letreiro, toldo vermelho e hambúrguer gigante no telhado, marcador **H** no minimapa) e entregue numa das 8 **casas** marcadas (**CASA 1 a 8**, marcador **C**). Durante a entrega a moto leva uma bolsa vermelha
- **Motos redesenhadas** (veja a garagem abaixo) e **grau pelo analógico** (sem botão GRAU)

### Novidades da Fase 4
- **Tela inicial, menu de pausa, missões e configurações** totalmente por toque (JOGAR, GARAGEM, MISSÕES, sensibilidade, opacidade dos controles, densidade do trânsito)
- **Garagem** com visualização 3D giratória (arraste para girar): 3 motos originais (**GC 125** clássica de meados de 2009, com farol redondo, garfo com sanfonas, amortecedores duplos e freio a tambor; **GC 160** utilitária moderna, com farol de LED, carenagens angulares, painel digital e rodas de liga; **TORRADO 300** trail alta, com bico, garfo invertido dourado, guidão alto com protetores e pneus de trilha), compra, pintura de carenagem/quadro/rodas, rodas esportivas, baú, escape esportivo, retrovisores, adesivos (listras, número 77) e 3 níveis de suspensão (afetam direção e inclinação). Tudo aparece no modelo 3D real; cores usam materiais compartilhados (nada de duplicar modelos)
- **Dinheiro e loja**: saldo no HUD, compra de motos e peças, saldo inicial R$ 500
- **8 missões**: 4 entregas (pegar e entregar com tempo), 2 desafios de grau (5 s e 10 s) e 2 percursos com checkpoints. Marcador 3D e no minimapa. Falha por tempo. Recompensa paga **uma vez por execução**; repetir a mesma missão paga 40%
- **Salvamento** em `user://save.json` com checksum, gravação atômica e backup `.bak`: arquivo corrompido ou ausente nunca derruba o jogo. Missão em andamento não é salva, então carregar não repete recompensa
- Para entrar na garagem durante o jogo, vá até o marcador **G** (a menos de 28 m) e use Pausa → Garagem

### Gráficos melhorados
- Motos com muito mais detalhe: tanque, motor com aletas, escapamento, garfo com bengalas, disco de freio, painel, farol/lanterna, pneus com perfil arredondado, raios, piloto com capacete, luvas e botas; cada estilo tem carenagem, guidão e posição de pilotagem próprios
- Cidade: texturas geradas por código (asfalto, concreto, fachadas com janelas, estuque, telhado), faixas laterais e de pedestre, prédios com platibanda, caixa d'água, antena e ar-condicionado, lojas com toldo e letreiro, casas com telhado e muro com portão, árvores, postes com braço, pátio de treino com pneus, posto com cobertura e bombas, oficina e garagem com portões e placas
- Carros em 3 estilos (sedã, hatch, van) com faróis, lanternas, para-choques, rodas e retrovisores
- Céu, névoa de distância, montanhas no horizonte e sombras em 2 níveis
- Cidade 3D de 200x200 m: grade de 3x3 cruzamentos, avenidas e ruas com faixas, ~40 prédios com colisão, postes, muros de limite
- Pontos de interesse: **garagem**, **oficina**, **posto de combustível**, **área de treino** (slalom e rampa) e 4 **pontos de entrega** (marcadores com nome; as missões vêm na Fase 4)
- **Trânsito simplificado**: carros seguem faixas pela mão direita, respeitam semáforos, freiam diante da moto e de outros carros, escolhem o trecho seguinte ao chegar nos cruzamentos; carros a mais de 110 m ficam congelados e ocultos; densidade configurável (`traffic_density` em `user://settings.cfg`, 0 a 30; padrão 10)
- Semáforos com ciclo de 20 s (as luzes dos postes são aproximadas: cantos opostos mostram o mesmo eixo)
- **Minimapa** no topo da tela (norte para cima) com ruas, pontos de interesse, carros e a moto
- Moto procedural com piloto, rodas que giram, garfo que esterça e inclinação em curva
- Física arcade-híbrida: aceleração, resistência, freio dianteiro/traseiro, direção, **grau com equilíbrio** (botão EQUIL estabiliza, com pontuação menor), **stoppie** (freio dianteiro forte em velocidade; muito rápido derruba), **borrachão** (DERRAP parado + ACEL), **derrapagem lateral** (DERRAP em curva), queda por batida ou por frear forte inclinado em alta velocidade, e reposicionamento
- Câmera em 3ª pessoa (botão VISÃO alterna para 1ª pessoa): segue suavemente, órbita 360° por gesto, zoom por pinça, anti-atravessar paredes, reset, persistência
- Controles de toque com multitoque (analógico de direção, ACEL, EQUIL, DERRAP, freios, VISÃO, CÂM, VOLTAR, PAUSA). **O grau é ativado puxando o analógico para trás** (dedo para baixo, junto com ACEL); o analógico mostra "GRAU!" quando ativo
- HUD (velocidade, pontos de grau, indicador de equilíbrio)
- Salvamento das configurações de câmera (`user://settings.cfg`), tolerante a arquivo corrompido
- Testes automatizados e workflow de build

## Como compilar pelo GitHub
1. Crie um repositório e envie todos os arquivos (branch `main`).
2. Abra a aba **Actions** → **Android Build**. Roda a cada push na `main` ou em **Run workflow**.
3. Ao terminar, baixe em **Artifacts**:
   - `motorcycle-game-debug-apk` → `motorcycle-game-debug.apk`
   - `motorcycle-game-source` → `motorcycle-game-source.zip`
   - `build-logs` (logs de import, testes e exportação)
4. Instale o APK no celular (permitir fontes desconhecidas).

### APK de release assinado (opcional)
Em *Settings → Secrets and variables → Actions*, crie: `ANDROID_KEYSTORE_BASE64` (keystore em base64),
`ANDROID_KEY_ALIAS` e `ANDROID_KEYSTORE_PASSWORD`. Com o primeiro secret presente, o workflow também
gera `motorcycle-game-release.apk`. Nunca coloque keystore ou senha no repositório.

## Rodar no computador
Abra a pasta no Godot 4.3 e aperte F5. Teclado: Esc pausa, W/↑ acelera, A/D ou ←/→ direção, Espaço grau,
Shift freio dianteiro, S/↓ freio traseiro, B equilíbrio, X derrapar, V troca 1ª/3ª pessoa, R reposiciona, C reseta câmera. Com mouse, os botões
virtuais também respondem a clique.

## Testes
```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```
Cobrem: arquivos e cenas principais, referências `res://` quebradas, inicialização da moto, acelerador,
freio, grau, equilíbrio assistido, stoppie, borrachão, derrapagem, reposicionamento, câmera (3ª e 1ª pessoa), salvamento/carregamento (inclusive arquivo corrompido)
geração da cidade, pontos de interesse, modelos das 3 motos e pintura, salvamento/backup/corrupção, loja, recompensas únicas, missões (entrega, grau, checkpoints, tempo, cancelamento), troca de moto, garagem e menus, movimento e permanência dos carros no mapa, alternância dos semáforos e instanciação da cena principal. A exportação do APK é validada no workflow (existência, tamanho e manifesto).
O que depende de aparelho real está em `docs/CHECKLIST_MANUAL.md`.

## Estrutura
- `scenes/main/` cena principal; `scripts/vehicle/` moto, modelo e perfil; `scripts/camera/` câmera;
  `scripts/ui/` controles e HUD; `scripts/city/` cidade; `scripts/traffic/` trânsito; `scripts/save/` configurações e estado do jogo; `scripts/missions/` missões; `scripts/ui/` também menus e garagem;
  `resources/vehicles/` perfis de moto (`.tres`); `tests/` testes; `.github/workflows/` build.
- Para criar outra moto: duplique `resources/vehicles/starter.tres` e ajuste os parâmetros.
- Para trocar o nome: `config/name` em `project.godot` e `package/name` em `export_presets.cfg`.
- Para mudar o pacote Android: `package/unique_name` em `export_presets.cfg`.

## Próximas fases
4 Garagem, missões,
dinheiro e salvamento completo · 5 Áudio, otimização e acabamento.

Licença: MIT (veja `LICENSE`).
