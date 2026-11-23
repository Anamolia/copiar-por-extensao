# Copiar por extensão

Script para macOS que pergunta uma extensão de arquivo e copia todos os arquivos com essa extensão de uma pasta para outra, usando janelas nativas do Mac. Feito pensando em SSDs/HDs externos.

## Como usar

1. Baixe o arquivo **`Copiar por extensão.command`**.
2. Dê dois cliques nele. Na primeira vez, se o macOS bloquear ("desenvolvedor não identificado"), clique com o botão direito → **Abrir**.
3. Responda às perguntas:
   - extensão (`pdf`, `epub`, `mp4`… — com ou sem ponto, maiúsculas ou minúsculas);
   - pasta de **origem** e pasta de **destino**;
   - se quer incluir as subpastas.
4. No fim, aparece um **resumo** com o total de arquivos e o tamanho copiado, separado em novos, substituídos e segunda cópia, além de erros, metadados `._` ignorados e o tempo gasto. Dá para abrir a pasta de destino direto dali.

Se o arquivo baixado não abrir, rode uma vez no Terminal:

```bash
chmod +x ~/Downloads/"Copiar por extensão.command"
```

## Comportamento

- **Nunca apaga nada** na origem.
- **Arquivo repetido no destino:** o script avisa e pergunta o que fazer:
  - **Cancelar transferência** — para tudo ali (o que já foi copiado fica);
  - **Substituir** — troca o arquivo do destino pelo da origem;
  - **Manter as duas** — salva a nova cópia como `nome (2).ext`, `nome (3).ext`…
  
  Ao escolher Substituir ou Manter as duas, ele pergunta se vale **só para este arquivo** ou para **todos** os próximos repetidos.
- Preserva as datas dos arquivos (`cp -p`).
- **Ignora os metadados `._*`** do macOS na origem e **não cria novos `._*` no destino** (usa `cp -X` e `COPYFILE_DISABLE=1`).
- Se o destino estiver dentro da origem, ele é ignorado na busca (não copia arquivos para cima de si mesmo).
- A pasta inicial das janelas é `/Volumes/SSD512GB`; troque a linha `INICIO=` no script para usar outro disco.

## Licença

MIT
