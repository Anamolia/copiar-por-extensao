#!/bin/bash
# Copiar por extensão — pergunta uma ou várias extensões e copia todos os arquivos
# dessas extensões de uma pasta para outra. Nunca apaga nada; só substitui
# um arquivo no destino se você escolher "Substituir".

export COPYFILE_DISABLE=1   # não deixa o macOS criar arquivos ._ no destino

pergunta() { osascript -e "$1" 2>/dev/null; }
# escapa texto para o AppleScript (aspas, barras e quebras de linha)
aspas() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'NR>1{printf "\\n"} {printf "%s",$0}'; }
# tamanho de um arquivo em bytes (macOS e Linux)
tamanho() { local t; if [ "$(uname)" = Darwin ]; then t=$(stat -f %z "$1" 2>/dev/null); else t=$(stat -c %s "$1" 2>/dev/null); fi; echo "${t:-0}"; }
# bytes -> "1,5 GB" (mesma escala do Finder: 1 KB = 1000 bytes)
legivel() { awk -v b="$1" 'BEGIN{ split("bytes KB MB GB TB",u," "); i=1; while (b>=1000 && i<5) {b/=1000; i++}
  if (i==1) printf "%d %s", b, u[i]; else { s=sprintf("%.1f %s", b, u[i]); sub(/\./, ",", s); printf "%s", s } }'; }

# 1. Extensões (uma ou várias, separadas por vírgula, espaço ou ponto e vírgula)
ENTRADA=$(pergunta 'text returned of (display dialog "Quais extensões você quer copiar?" & return & "Separe por vírgula ou espaço (ex.: epub, mobi, pdf, azw3)" default answer "" with title "Copiar por extensão" buttons {"Cancelar","Continuar"} default button "Continuar" cancel button "Cancelar")')
[ -z "$ENTRADA" ] && exit 0
EXTS=(); INVALIDAS=""
set -f   # evita que * ou ? digitados virem nomes de arquivo
for e in $(printf '%s' "$ENTRADA" | tr ',;' '  '); do
  e="${e#.}"; e=$(printf '%s' "$e" | tr '[:upper:]' '[:lower:]')
  [ -z "$e" ] && continue
  case "$e" in *[!a-z0-9._-]*) INVALIDAS="$INVALIDAS $e"; continue ;; esac   # só letras, números, . _ -
  repetida=0; for x in "${EXTS[@]}"; do [ "$x" = "$e" ] && repetida=1; done
  [ $repetida -eq 0 ] && EXTS+=("$e")
done
set +f
[ ${#EXTS[@]} -eq 0 ] && { pergunta 'display alert "Nenhuma extensão válida informada."'; exit 1; }
[ -n "$INVALIDAS" ] && pergunta "display dialog \"Ignorando o que não é extensão válida:$(aspas "$INVALIDAS")\" with title \"Copiar por extensão\" buttons {\"OK\"} default button \"OK\"" >/dev/null

# Texto ".epub, .mobi, .pdf" e filtro do find: ( -iname "*.epub" -o -iname "*.mobi" ... )
LISTA=""; FILTRO=( "(" )
for i in "${!EXTS[@]}"; do
  [ $i -gt 0 ] && { LISTA="$LISTA, "; FILTRO+=( -o ); }
  LISTA="$LISTA.${EXTS[$i]}"; FILTRO+=( -iname "*.${EXTS[$i]}" )
  N_EXT[$i]=0; B_EXT[$i]=0
done
FILTRO+=( ")" )
# índice da extensão de um arquivo (para o resumo por extensão)
indice_ext() {
  local n; n=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  for i in "${!EXTS[@]}"; do [[ "$n" == *."${EXTS[$i]}" ]] && { echo $i; return; }; done; echo 0
}

# 2. Pastas de origem e destino (abre no SSD por padrão)
INICIO='POSIX file "/Volumes/SSD512GB"'
ORIGEM=$(pergunta "POSIX path of (choose folder with prompt \"Escolha a pasta de ORIGEM (onde estão os $LISTA):\" default location ($INICIO))")
[ -z "$ORIGEM" ] && exit 0
DESTINO=$(pergunta "POSIX path of (choose folder with prompt \"Escolha a pasta de DESTINO:\" default location ($INICIO))")
[ -z "$DESTINO" ] && exit 0
ORIGEM="${ORIGEM%/}"; DESTINO="${DESTINO%/}"
if [ "$ORIGEM" = "$DESTINO" ]; then
  pergunta 'display alert "A origem e o destino são a mesma pasta."'; exit 1
fi

# 3. Incluir subpastas?
SUB=$(pergunta 'button returned of (display dialog "Incluir também os arquivos que estão dentro das subpastas?" with title "Copiar por extensão" buttons {"Só esta pasta","Incluir subpastas"} default button "Incluir subpastas")')
[ "$SUB" = "Só esta pasta" ] && PROF="-maxdepth 1" || PROF=""

# Nome livre "nome (2).ext", "nome (3).ext"... para manter as duas cópias
nome_livre() {
  local nome="$1" base ext n=2
  if [[ "$nome" == *.* ]]; then base="${nome%.*}"; ext=".${nome##*.}"; else base="$nome"; ext=""; fi
  while [ -e "$DESTINO/$base ($n)$ext" ]; do n=$((n+1)); done
  printf '%s' "$DESTINO/$base ($n)$ext"
}

# 4. Copiar (ignora a pasta de destino e os arquivos de metadados ._ do macOS)
copiados=0; substituidos=0; duplicados=0; pulados=0; erros=0; cancelado=0
b_copiados=0; b_substituidos=0; b_duplicados=0; b_pulados=0
PARA_TODOS=""      # vazio = perguntar a cada conflito; senão, a escolha vale para todos os repetidos
ignorados=$(find "$ORIGEM" $PROF -path "$DESTINO" -prune -o -type f -name "._*" "${FILTRO[@]}" -print | wc -l | tr -d ' ')
INICIO_T=$(date +%s)
echo "Copiando arquivos $LISTA de:"; echo "  $ORIGEM"; echo "para:"; echo "  $DESTINO"; echo
while IFS= read -r -d '' arq; do
  nome=$(basename "$arq")
  alvo="$DESTINO/$nome"
  acao="copiar"

  if [ -e "$alvo" ]; then
    if [ -n "$PARA_TODOS" ]; then
      escolha="$PARA_TODOS"
    else
      n_esc=$(aspas "$nome")
      # lista de opções (o diálogo comum do macOS só aceita 3 botões)
      escolha=$(pergunta "choose from list {\"Pular (não copiar este arquivo)\", \"Substituir o do destino\", \"Manter as duas cópias\"} with title \"Arquivo já existe\" with prompt \"O arquivo \\\"$n_esc\\\" já existe na pasta de destino. O que você quer fazer?\" default items {\"Pular (não copiar este arquivo)\"} OK button name \"Continuar\" cancel button name \"Cancelar transferência\"")
      case "$escolha" in
        Pular*)      escolha="Pular" ;;
        Substituir*) escolha="Substituir" ;;
        Manter*)     escolha="Manter as duas" ;;
        *)           escolha="Cancelar" ;;
      esac
      if [ "$escolha" != "Cancelar" ]; then
        quanto=$(pergunta "button returned of (display dialog \"$escolha: aplicar só a este arquivo ou a todos os próximos arquivos repetidos?\" with title \"Arquivo já existe\" buttons {\"Só este arquivo\",\"Todos\"} default button \"Só este arquivo\")")
        [ "$quanto" = "Todos" ] && PARA_TODOS="$escolha"
      fi
    fi
    case "$escolha" in
      "Pular")          tam=$(tamanho "$arq"); pulados=$((pulados+1)); b_pulados=$((b_pulados+tam))
                        echo "↷ $nome (já existe, pulado)"; continue ;;
      "Substituir")     acao="substituir" ;;
      "Manter as duas") acao="duplicar"; alvo=$(nome_livre "$nome") ;;
      *)                cancelado=1; echo "■ Transferência cancelada em: $nome"; break ;;
    esac
  fi

  # -X: não copia atributos estendidos, então o macOS não cria ._ no destino
  if cp -pX "$arq" "$alvo"; then
    tam=$(tamanho "$arq")
    ix=$(indice_ext "$nome"); N_EXT[$ix]=$(( ${N_EXT[$ix]} + 1 )); B_EXT[$ix]=$(( ${B_EXT[$ix]} + tam ))
    case "$acao" in
      copiar)     copiados=$((copiados+1));         b_copiados=$((b_copiados+tam));         echo "✓ $nome ($(legivel $tam))" ;;
      substituir) substituidos=$((substituidos+1)); b_substituidos=$((b_substituidos+tam)); echo "↻ $nome ($(legivel $tam), substituído)" ;;
      duplicar)   duplicados=$((duplicados+1));     b_duplicados=$((b_duplicados+tam));     echo "⧉ $nome → $(basename "$alvo") ($(legivel $tam))" ;;
    esac
  else
    erros=$((erros+1)); echo "✗ ERRO: $arq"
  fi
done < <(find "$ORIGEM" $PROF -path "$DESTINO" -prune -o -type f "${FILTRO[@]}" ! -name '._*' -print0)

# 5. Resumo
total=$((copiados+substituidos+duplicados))
b_total=$((b_copiados+b_substituidos+b_duplicados))
seg=$(( $(date +%s) - INICIO_T )); tempo="$((seg/60)) min $((seg%60)) s"

if [ $total -eq 0 ] && [ $erros -eq 0 ] && [ $cancelado -eq 0 ] && [ $pulados -eq 0 ]; then
  MSG="Nenhum arquivo $LISTA encontrado na origem."
else
  MSG="RESUMO DA CÓPIA ($LISTA)"
  [ $cancelado -eq 1 ] && MSG="$MSG — transferência cancelada"
  MSG="$MSG

Total copiado: $total arquivo(s) — $(legivel $b_total)"
  [ $copiados -gt 0 ]     && MSG="$MSG
• Novos: $copiados — $(legivel $b_copiados)"
  [ $substituidos -gt 0 ] && MSG="$MSG
• Substituídos: $substituidos — $(legivel $b_substituidos)"
  [ $duplicados -gt 0 ]   && MSG="$MSG
• Segunda cópia: $duplicados — $(legivel $b_duplicados)"
  [ $pulados -gt 0 ]      && MSG="$MSG
• Pulados (já existiam no destino): $pulados — $(legivel $b_pulados)"
  if [ ${#EXTS[@]} -gt 1 ]; then
    MSG="$MSG

Por extensão:"
    for i in "${!EXTS[@]}"; do MSG="$MSG
• .${EXTS[$i]}: ${N_EXT[$i]} — $(legivel ${B_EXT[$i]})"; done
    MSG="$MSG
"
  fi
  [ $erros -gt 0 ]        && MSG="$MSG
• Com erro: $erros (veja a janela do Terminal)"
  [ "$ignorados" -gt 0 ]  && MSG="$MSG
• Metadados ._ ignorados: $ignorados"
  MSG="$MSG

Tempo: $tempo"
fi
echo; echo "$MSG"
pergunta "display dialog \"$(aspas "$MSG")\" with title \"Copiar por extensão\" buttons {\"Abrir destino\",\"OK\"} default button \"OK\"" | grep -q "Abrir destino" && open "$DESTINO"
