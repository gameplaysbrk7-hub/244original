# Moto Grau (nome provisório)

Jogo 3D de motos para Android feito em **Godot 4.3** (GDScript tipado, renderizador Compatibility),
inspirado na pilotagem com grau de jogos de motos brasileiros. Projeto original: sem assets de terceiros,
tudo é gerado proceduralmente.

> **Estado: versão 1.0 (Fase 5 concluída): acabamento, áudio, dia e noite, desempenho.** Ainda **não foi testado em aparelho real nem compilado pelo autor deste
> código**: o primeiro build no GitHub Actions é o teste de verdade. Se algo falhar, abra o log da
> execução (artefato `build-logs`) e corrija a partir dele.

## O que já existe

### Celular (v1.4)
- **Botão do celular** (só a imagem, sem texto) na parte de baixo da tela, na moto e a pé. Toque: o celular **sobe da borda inferior** e fica inteiro visível do lado direito. O **X** pequeno no canto superior direito fecha (o celular desce). Tecla P no teclado
- **Em tempo real**: abrir o celular ou qualquer app **não pausa** o jogo (trânsito, física, relógio, entregas e corridas continuam). Só o botão **PAUSA** pausa. (Exceção: o editor de reposicionar botões pausa, para ninguém bater a moto enquanto arrasta.) Toques sobre o aparelho não controlam o jogo
- **Duas imagens**: tela inicial com os ícones e, ao abrir qualquer app, troca na hora para a imagem de **fundo preto**; o app aparece **dentro da tela do aparelho**. A imagem de fundo preto foi **gerada a partir da sua imagem original** (`assets/ui/phone_app.png`); se quiser, troque pelo arquivo do seu design (mesmo tamanho, 555x1041)
- **HOME** (círculo da barra de navegação) volta à tela inicial em qualquer app; o triângulo volta uma etapa dentro do app
- **Mapa**: o celular se aproxima da câmera e **gira 90 graus** até ocupar a tela, na horizontal; mapa grande com nomes, a vista segue o jogador. A **seta amarela** agora fica na posição real do personagem (a pé ou na moto) e mostra a direção. HOME desfaz a rotação e o zoom gradualmente
- **Entregas** (estilo app de delivery): **uma oferta por vez** com **ACEITAR** e **RECUSAR** (recusar sorteia outra, sem repetir as recusadas recentes). Painel com **entregas concluídas**, **total recebido só com entregas** e entregas da **sessão** (desde que o jogo foi aberto). Fluxo: aceitar -> o mapa aponta a hamburgueria -> botão de interação **COLETAR** -> ir ao cliente -> abrir o celular em Entregas -> **ENTREGAR** (aparece só no endereço certo). A entrega **não** usa mais o botão do mundo e **nada é automático**
- **Corridas**: mesma estrutura (oferta única, ACEITAR/RECUSAR, aleatória), com **estatísticas e ganhos próprios**, separados das entregas. Usa os desafios de grau e os percursos com checkpoints que já existiam
- **Configurações** (estilo smartphone, com ícones e subpáginas): **Gráficos** (qualidade, resolução, distância de renderização, sombras, efeitos visuais), **Controles** (reposicionar botões, tamanho, sensibilidade da direção e da câmera, opacidade), **Áudio** (geral, motor e efeitos, ambiente; o jogo ainda não tem música) e **Jogabilidade** (trânsito, duração do dia, 1ª pessoa, minimapa). Tudo age de verdade e fica salvo
- **Telefone**: teclado de discador (0-9, *, #) com **tons de tecla** e resposta visual (os números não aparecem) e o contato **GUINCHO** com o valor realmente cobrado; ao tocar, aciona o guincho e **fecha o celular**
- **Câmera**: tira foto da tela sem interface (Imagens do aparelho, pasta GCMotoGrau; se o Android não permitir, salva em `user://fotos`)
- **Animação a pé**: ao abrir o celular fora da moto o personagem **tira o celular do bolso** e o segura; ao fechar, **guarda no bolso**. Na moto não há essa animação
- **Primeira pessoa**: a câmera acompanha a **cabeça real** do personagem (inclina, balança ao andar, gira), tanto pilotando quanto a pé; o capacete some só nessa visão
- **Bag de entregas**: agora fica **nas costas do personagem** (acompanha o tronco, sobe e desce da moto com ele, aparece a pé), não mais presa à moto

### Ré, andar a pé e queda
- **Ré**: com a moto parada, toque no **freio traseiro** (um toque novo, sem estar freando em movimento) e a moto anda de ré devagar. O piloto apoia os **pés no chão** e dá passos, olhando para trás. O HUD mostra "RÉ". Na moto parada o piloto também apoia um pé no chão
- **Descer e subir**: botão **DESCER** (topo da tela) com a moto quase parada; a pé aparece o botão **SUBIR** quando você está perto da moto. Animações de descer e subir
- **A pé**: analógico para andar (relativo à câmera) e botão **CORRER** (segure). Animações de **caminhar** e **correr** (cinemática inversa de pernas e braços), som de passos, câmera livre. A cidade, as missões (entregas a pé funcionam), o minimapa e o trânsito acompanham o personagem; os carros param para ele
- **Cair da moto**: ao bater, o piloto é **arremessado**, desliza, e se levanta. A moto **fica no chão** até você ir até ela e tocar em **LEVANTAR** (animação de levantar a moto); depois toque em **SUBIR** para pilotar de novo. Se a moto ficar presa ou longe, **VOLTAR** reposiciona a moto ao lado do personagem
- **Piloto novo**: agora é um personagem articulado (o mesmo da caminhada). O artefato da cor da moto que aparecia no peito foi removido

### Fase 5 (acabamento)
- **Áudio gerado por código** (nenhum arquivo de som externo): motor com rotação e **troca de marchas** (5 marchas), rajada de motor no borrachão, **derrapagem e frenagem**, vento proporcional à velocidade, **ambiente urbano**, **impactos**, **queda**, cliques de interface e jingles de missão (sucesso e falha). Volume geral, motor/efeitos e ambiente ajustáveis; o som pausa junto com o jogo
- **Ciclo de dia e noite**: sol e lua, céu, névoa e luz ambiente mudam; ao anoitecer acendem **janelas e vitrines**, o **farol da moto** e 4 luzes de poste reaproveitadas junto do jogador (limite de luzes dinâmicas). Relógio no HUD; duração do dia configurável (0 = tempo parado)
- **Qualidade gráfica** Automática/Baixa/Média/Alta: sombras, alcance de visão, resolução 3D, alcance e teto de carros. No modo automático, uma **proteção de desempenho** reduz a qualidade (nunca aumenta) se o FPS ficar abaixo de 24 por 6 segundos. Limite de 60 FPS para poupar bateria. Peças pequenas do cenário somem a 150 m
- **Reposicionar controles**: Configurações → Controles → REPOSICIONAR CONTROLES; arraste cada botão onde quiser; as posições são salvas
- Configurações em abas (Controles, Som, Gráficos); versão 1.0.0 no preset Android

> **Metas de desempenho (30 FPS em celulares modestos, 60 FPS nos bons) NÃO foram verificadas**: não houve teste em aparelho real. Os testes automáticos cobrem a lógica da qualidade e da proteção, mas o FPS real só se mede no celular (use o checklist).

### Ajustes recentes
- **Trânsito corrigido:** os carros agora circulam pelas ruas (mão direita, semáforos, curvas nos cruzamentos). A detecção de obstáculos passou a ser por geometria simples (sem consultas de física) e carros parados sem motivo por mais de 10 s são reposicionados
- **Botão de interação (substitui o EQUIL):** aparece só quando você está **parado sobre um acionador** (marcador no chão) e muda de nome: **GARAGEM** (na garagem, abre a garagem direto, sem passar pela pausa), **COLETAR** (na hamburgueria da entrega aceita no app Entregas). A conclusão da entrega é feita pelo botão ENTREGAR dentro do app
- **Entregas:** o pedido é retirado numa **HAMBURGUERIA** (prédio com letreiro, toldo vermelho e hambúrguer gigante no telhado, marcador **H** no minimapa) o botão ENTREGA sorteia uma das **casas** (CASA 1 a 8, marcador **C**, a pelo menos 50 m). Tempo e recompensa dependem da distância; repetir o mesmo trajeto paga 40%. A moto leva uma bolsa vermelha durante a entrega; funciona também a pé
- **Motos redesenhadas** (veja a garagem abaixo) e **grau pelo analógico** (sem botão GRAU)

### Novidades da Fase 4
- **Tela inicial, menu de pausa, missões e configurações** totalmente por toque (JOGAR, GARAGEM, MISSÕES, sensibilidade, opacidade dos controles, densidade do trânsito)
- **Garagem** com visualização 3D giratória (arraste para girar): 3 motos originais (**GC 125** clássica de meados de 2009, com farol redondo, garfo com sanfonas, amortecedores duplos e freio a tambor; **GC 160** utilitária moderna, com farol de LED, carenagens angulares, painel digital e rodas de liga; **TORRADO 300** trail alta, com bico, garfo invertido dourado, guidão alto com protetores e pneus de trilha), compra, pintura de carenagem/quadro/rodas, rodas esportivas, baú, escape esportivo, retrovisores, adesivos (listras, número 77) e 3 níveis de suspensão (afetam direção e inclinação). Tudo aparece no modelo 3D real; cores usam materiais compartilhados (nada de duplicar modelos)
- **Dinheiro e loja**: saldo no HUD, compra de motos e peças, saldo inicial R$ 500
- **Missões**: entregas sorteadas nas hamburguerias (botão ENTREGA) e, pelo menu Pausa → Missões, 2 desafios de grau (5 s e 10 s) e 2 percursos com checkpoints. Marcador 3D e no minimapa. Falha por tempo. Recompensa paga **uma vez por execução**; repetir a mesma missão paga 40%
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
- Física arcade-híbrida: aceleração, resistência, freio dianteiro/traseiro, direção, **grau com equilíbrio** (a assistência de equilíbrio agora só existe no teclado, tecla B), **stoppie** (freio dianteiro forte em velocidade; muito rápido derruba), **borrachão** (DERRAP parado + ACEL), **derrapagem lateral** (DERRAP em curva), queda por batida ou por frear forte inclinado em alta velocidade, e reposicionamento
- Câmera em 3ª pessoa (botão VISÃO alterna para 1ª pessoa): segue suavemente, órbita 360° por gesto, zoom por pinça, anti-atravessar paredes, reset, persistência
- Controles de toque com multitoque (analógico de direção, ACEL, DERRAP, freios, VISÃO, CÂM, VOLTAR, PAUSA e o botão de interação que aparece sobre os acionadores). **O grau é ativado puxando o analógico para trás** (dedo para baixo, junto com ACEL); o analógico mostra "GRAU!" quando ativo
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
sons gerados, áudio (rotação, derrapagem, volume), dia/noite (sol, janelas, farol, relógio), qualidade gráfica e proteção de FPS, reposicionamento de controles, configurações finais, geração da cidade, pontos de interesse, modelos das 3 motos e pintura, salvamento/backup/corrupção, loja, recompensas únicas, missões (entrega, grau, checkpoints, tempo, cancelamento), troca de moto, garagem e menus, movimento e permanência dos carros no mapa, alternância dos semáforos e instanciação da cena principal. A exportação do APK é validada no workflow (existência, tamanho e manifesto).
O que depende de aparelho real está em `docs/CHECKLIST_MANUAL.md`.

## Estrutura
- `scenes/main/` cena principal; `scripts/vehicle/` moto, modelo e perfil; `scripts/camera/` câmera;
  `scripts/ui/` controles e HUD; `scripts/city/` cidade e ciclo dia/noite; `scripts/traffic/` trânsito; `scripts/audio/` sons gerados por código; `scripts/core/` qualidade gráfica e proteção de desempenho; `scripts/save/` configurações e estado do jogo; `scripts/missions/` missões; `scripts/ui/` também menus e garagem;
  `resources/vehicles/` perfis de moto (`.tres`); `tests/` testes; `.github/workflows/` build.
- Para criar outra moto: duplique `resources/vehicles/starter.tres` e ajuste os parâmetros.
- Para trocar o nome: `config/name` em `project.godot` e `package/name` em `export_presets.cfg`.
- Para mudar o pacote Android: `package/unique_name` em `export_presets.cfg`.

## Ideias futuras
Mais motos e peças, mais missões, clima (chuva), sons gravados originais, mapa maior, pedestres, modo multijogador local.

Licença: MIT (veja `LICENSE`).
