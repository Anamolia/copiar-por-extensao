#!/bin/bash
# Copiar por extensão — pergunta uma extensão e copia todos os arquivos
# dessa extensão de uma pasta para outra. Nunca apaga nada; só substitui
# um arquivo no destino se você escolher "Substituir".

pergunta() { osascript -e "$1" 2>/dev/null; }
aspas() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }   # escapa texto para o AppleScript

# 1. Extensão
EXT=$(pergunta 'text returned of (display dialog "Qual extensão você quer copiar?" & return & "(ex.: pdf, epub, jpg, mp4)" default answer "" with title "Copiar por extensão" buttons {"Cancelar","Continuar"} default button "Continuar" cancel button "Cancelar")')
[ -z "$EXT" ] && exit 0
EXT="${EXT#.}"; EXT="${EXT// /}"
[ -z "$EXT" ] && { pergunta 'display alert "Extensão vazia."'; exit 1; }

# 2. Pastas de origem e destino (abre no SSD por padrão)
INICIO='POSIX file "/Volumes/SSD512GB"'
ORIGEM=$(pergunta "POSIX path of (choose folder with prompt \"Escolha a pasta de ORIGEM (onde estão os .$EXT):\" default location ($INICIO))")
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

# 4. Copiar (ignora a pasta de destino e os arquivos ocultos ._ do macOS)
copiados=0; substituidos=0; duplicados=0; erros=0; cancelado=0
PARA_TODOS=""      # vazio = perguntar a cada conflito; "Substituir" ou "Manter as duas" = vale para todos
echo "Copiando arquivos .$EXT de:"; echo "  $ORIGEM"; echo "para:"; echo "  $DESTINO"; echo
while IFS= read -r -d '' arq; do
  nome=$(basename "$arq")
  alvo="$DESTINO/$nome"
  acao="copiar"

  if [ -e "$alvo" ]; then
    if [ -n "$PARA_TODOS" ]; then
      escolha="$PARA_TODOS"
    else
      n_esc=$(aspas "$nome")
      escolha=$(pergunta "button returned of (display dialog \"O arquivo \\\"$n_esc\\\" já existe na pasta de destino.\" & return & return & \"O que você quer fazer?\" with title \"Arquivo já existe\" with icon caution buttons {\"Cancelar transferência\",\"Manter as duas\",\"Substituir\"} default button \"Manter as duas\")")
      if [ "$escolha" = "Substituir" ] || [ "$escolha" = "Manter as duas" ]; then
        quanto=$(pergunta "button returned of (display dialog \"$escolha: aplicar só a este arquivo ou a todos os próximos arquivos repetidos?\" with title \"Arquivo já existe\" buttons {\"Só este arquivo\",\"Todos\"} default button \"Só este arquivo\")")
        [ "$quanto" = "Todos" ] && PARA_TODOS="$escolha"
      fi
    fi
    case "$escolha" in
      "Substituir")     acao="substituir" ;;
      "Manter as duas") acao="duplicar"; alvo=$(nome_livre "$nome") ;;
      *)                cancelado=1; echo "■ Transferência cancelada em: $nome"; break ;;
    esac
  fi

  if cp -p "$arq" "$alvo"; then
    case "$acao" in
      copiar)     copiados=$((copiados+1));         echo "✓ $nome" ;;
      substituir) substituidos=$((substituidos+1)); echo "↻ $nome (substituído)" ;;
      duplicar)   duplicados=$((duplicados+1));     echo "⧉ $nome → $(basename "$alvo")" ;;
    esac
  else
    erros=$((erros+1)); echo "✗ ERRO: $arq"
  fi
done < <(find "$ORIGEM" $PROF -path "$DESTINO" -prune -o -type f -iname "*.$EXT" ! -name '._*' -print0)

# 5. Resultado
total=$((copiados+substituidos+duplicados))
MSG="$total arquivo(s) .$EXT copiado(s)."
[ $substituidos -gt 0 ] && MSG="$MSG $substituidos substituído(s)."
[ $duplicados -gt 0 ] && MSG="$MSG $duplicados salvo(s) como segunda cópia."
[ $erros -gt 0 ] && MSG="$MSG $erros com erro (veja a janela do Terminal)."
[ $cancelado -eq 1 ] && MSG="Transferência cancelada. $MSG"
[ $total -eq 0 ] && [ $erros -eq 0 ] && [ $cancelado -eq 0 ] && MSG="Nenhum arquivo .$EXT encontrado na origem."
echo; echo "$MSG"
pergunta "display dialog \"$(aspas "$MSG")\" with title \"Copiar por extensão\" buttons {\"Abrir destino\",\"OK\"} default button \"OK\"" | grep -q "Abrir destino" && open "$DESTINO"
