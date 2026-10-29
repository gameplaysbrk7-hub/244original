# Moto Grau (nome provisório)

Jogo 3D de motos para Android feito em **Godot 4.3** (GDScript tipado, renderizador Compatibility),
inspirado na pilotagem com grau de jogos de motos brasileiros. Projeto original: sem assets de terceiros,
tudo é gerado proceduralmente.

> **Estado: Fase 3 (cidade e trânsito) sobre as Fases 1 e 2.** Ainda **não foi testado em aparelho real nem compilado pelo autor deste
> código**: o primeiro build no GitHub Actions é o teste de verdade. Se algo falhar, abra o log da
> execução (artefato `build-logs`) e corrija a partir dele.

## O que já existe
- Cidade 3D de 200x200 m: grade de 3x3 cruzamentos, avenidas e ruas com faixas, ~40 prédios com colisão, postes, muros de limite
- Pontos de interesse: **garagem**, **oficina**, **posto de combustível**, **área de treino** (slalom e rampa) e 4 **pontos de entrega** (marcadores com nome; as missões vêm na Fase 4)
- **Trânsito simplificado**: carros seguem faixas pela mão direita, respeitam semáforos, freiam diante da moto e de outros carros, escolhem o trecho seguinte ao chegar nos cruzamentos; carros a mais de 110 m ficam congelados e ocultos; densidade configurável (`traffic_density` em `user://settings.cfg`, 0 a 30; padrão 10)
- Semáforos com ciclo de 20 s (as luzes dos postes são aproximadas: cantos opostos mostram o mesmo eixo)
- **Minimapa** no topo da tela (norte para cima) com ruas, pontos de interesse, carros e a moto
- Moto procedural com piloto, rodas que giram, garfo que esterça e inclinação em curva
- Física arcade-híbrida: aceleração, resistência, freio dianteiro/traseiro, direção, **grau com equilíbrio** (botão EQUIL estabiliza, com pontuação menor), **stoppie** (freio dianteiro forte em velocidade; muito rápido derruba), **borrachão** (DERRAP parado + ACEL), **derrapagem lateral** (DERRAP em curva), queda por batida ou por frear forte inclinado em alta velocidade, e reposicionamento
- Câmera em 3ª pessoa (botão VISÃO alterna para 1ª pessoa): segue suavemente, órbita 360° por gesto, zoom por pinça, anti-atravessar paredes, reset, persistência
- Controles de toque com multitoque (direção, ACEL, GRAU, EQUIL, DERRAP, freios, VISÃO, CÂM, VOLTAR, PAUSA)
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
Abra a pasta no Godot 4.3 e aperte F5. Teclado: W/↑ acelera, A/D ou ←/→ direção, Espaço grau,
Shift freio dianteiro, S/↓ freio traseiro, B equilíbrio, X derrapar, V troca 1ª/3ª pessoa, R reposiciona, C reseta câmera. Com mouse, os botões
virtuais também respondem a clique.

## Testes
```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```
Cobrem: arquivos e cenas principais, referências `res://` quebradas, inicialização da moto, acelerador,
freio, grau, equilíbrio assistido, stoppie, borrachão, derrapagem, reposicionamento, câmera (3ª e 1ª pessoa), salvamento/carregamento (inclusive arquivo corrompido)
geração da cidade, pontos de interesse, movimento e permanência dos carros no mapa, alternância dos semáforos e instanciação da cena principal. A exportação do APK é validada no workflow (existência, tamanho e manifesto).
O que depende de aparelho real está em `docs/CHECKLIST_MANUAL.md`.

## Estrutura
- `scenes/main/` cena principal; `scripts/vehicle/` moto, modelo e perfil; `scripts/camera/` câmera;
  `scripts/ui/` controles e HUD; `scripts/city/` cidade; `scripts/traffic/` trânsito; `scripts/save/` configurações;
  `resources/vehicles/` perfis de moto (`.tres`); `tests/` testes; `.github/workflows/` build.
- Para criar outra moto: duplique `resources/vehicles/starter.tres` e ajuste os parâmetros.
- Para trocar o nome: `config/name` em `project.godot` e `package/name` em `export_presets.cfg`.
- Para mudar o pacote Android: `package/unique_name` em `export_presets.cfg`.

## Próximas fases
4 Garagem, missões,
dinheiro e salvamento completo · 5 Áudio, otimização e acabamento.

Licença: MIT (veja `LICENSE`).
