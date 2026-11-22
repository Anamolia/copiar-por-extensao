# Copiar por extensão

Script para macOS que pergunta uma extensão de arquivo e copia todos os arquivos com essa extensão de uma pasta para outra, usando janelas nativas do Mac. Feito pensando em SSDs/HDs externos.

## Como usar

1. Baixe o arquivo **`Copiar por extensão.command`**.
2. Dê dois cliques nele. Na primeira vez, se o macOS bloquear ("desenvolvedor não identificado"), clique com o botão direito → **Abrir**.
3. Responda às perguntas:
   - extensão (`pdf`, `epub`, `mp4`… — com ou sem ponto, maiúsculas ou minúsculas);
   - pasta de **origem** e pasta de **destino**;
   - se quer incluir as subpastas.
4. No fim, uma janela mostra quantos arquivos foram copiados e oferece abrir a pasta de destino.

Se o arquivo baixado não abrir, rode uma vez no Terminal:

```bash
chmod +x ~/Downloads/"Copiar por extensão.command"
```

## Comportamento

- **Só copia** — nunca apaga nem move nada.
- **Nunca sobrescreve**: se o nome já existir no destino, salva como `nome (2).ext`, `nome (3).ext`…
- Preserva as datas dos arquivos (`cp -p`).
- Ignora os arquivos ocultos `._*` que o macOS cria em discos externos.
- Se o destino estiver dentro da origem, ele é ignorado na busca (não copia arquivos para cima de si mesmo).
- A pasta inicial das janelas é `/Volumes/SSD512GB`; troque a linha `INICIO=` no script para usar outro disco.

## Licença

MIT
