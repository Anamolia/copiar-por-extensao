#!/bin/bash
# Copiar por extensão — pergunta uma extensão e copia todos os arquivos
# dessa extensão de uma pasta para outra. Nunca apaga nem sobrescreve nada.

pergunta() { osascript -e "$1" 2>/dev/null; }

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

# 4. Copiar (ignora a pasta de destino, os arquivos ocultos ._ do macOS e nunca sobrescreve)
copiados=0; erros=0
echo "Copiando arquivos .$EXT de:"; echo "  $ORIGEM"; echo "para:"; echo "  $DESTINO"; echo
while IFS= read -r -d '' arq; do
  nome=$(basename "$arq")
  alvo="$DESTINO/$nome"
  if [ -e "$alvo" ]; then          # já existe: cria "nome (2).ext", "nome (3).ext"...
    base="${nome%.*}"; ext="${nome##*.}"; n=2
    while [ -e "$DESTINO/$base ($n).$ext" ]; do n=$((n+1)); done
    alvo="$DESTINO/$base ($n).$ext"
  fi
  if cp -p "$arq" "$alvo"; then
    copiados=$((copiados+1)); echo "✓ $nome"
  else
    erros=$((erros+1)); echo "✗ ERRO: $arq"
  fi
done < <(find "$ORIGEM" $PROF -path "$DESTINO" -prune -o -type f -iname "*.$EXT" ! -name '._*' -print0)

# 5. Resultado
MSG="$copiados arquivo(s) .$EXT copiado(s)."
[ $erros -gt 0 ] && MSG="$MSG $erros com erro (veja a janela do Terminal)."
[ $copiados -eq 0 ] && [ $erros -eq 0 ] && MSG="Nenhum arquivo .$EXT encontrado na origem."
echo; echo "$MSG"
pergunta "display dialog \"$MSG\" with title \"Copiar por extensão\" buttons {\"Abrir destino\",\"OK\"} default button \"OK\"" | grep -q "Abrir destino" && open "$DESTINO"
