"""
icon-fetcher.py. Baixa icones do Iconify em dois temas (light + dark).

Uso a partir de uma skill:
    python icon-fetcher.py "<query-em-portugues>" "<pasta-destino>"
    python icon-fetcher.py "regua de pedreiro" "C:/.../MeuBotao.pushbutton"
    python icon-fetcher.py "lucide:ruler" "C:/.../MeuBotao.pushbutton"

Gera dois arquivos PNG 96x96 transparente:
    {pasta-destino}/icon.png       (linhas cinza #344054, tema claro)
    {pasta-destino}/icon.dark.png  (linhas brancas #FFFFFF, tema escuro)

Aceita dois formatos de query:
    1. Nome exato do icone do Iconify (ex: "lucide:ruler", "material-symbols:square-foot")
       Usa direto sem busca.
    2. Termo em portugues (ex: "regua", "parede", "porta")
       Traduz para ingles e busca via Iconify search API.

Bibliotecas curadas (priorizadas na busca):
    lucide, material-symbols, tabler, mdi, phosphor, ph

Requisitos:
    Python 3.6+ com urllib (built-in). Sem dependencias extras.

Saida no stdout:
    JSON com {success, icon_name, files: [icon.png, icon.dark.png]}
    ou {success: false, error: "..."}
"""

import os
import sys
import json
import urllib.request
import urllib.parse


# Bibliotecas Iconify priorizadas (estilo coerente e mais conhecidas)
PREFERRED_LIBS = ["lucide", "material-symbols", "tabler", "mdi", "phosphor", "ph", "heroicons"]

# Mapeamento PT -> EN para termos comuns no contexto Revit/BIM
PT_TO_EN = {
    # Elementos arquitetonicos
    "parede": "wall",
    "paredes": "wall",
    "porta": "door",
    "portas": "door",
    "janela": "window",
    "janelas": "window",
    "piso": "floor",
    "pisos": "floor",
    "forro": "ceiling",
    "forros": "ceiling",
    "telhado": "roof",
    "telhados": "roof",
    "cobertura": "roof",
    "ambiente": "room",
    "ambientes": "room",
    "comodo": "room",
    "comodos": "room",
    "area": "area",
    "areas": "area",
    "nivel": "level",
    "niveis": "level",
    "eixo": "grid",
    "eixos": "grid",
    "coluna": "column",
    "colunas": "column",
    "viga": "beam",
    "vigas": "beam",
    "escada": "stairs",
    "escadas": "stairs",
    "rampa": "ramp",
    "rampas": "ramp",
    "guarda-corpo": "railing",
    "guarda corpo": "railing",
    # Operacoes
    "cota": "ruler",
    "cotas": "ruler",
    "dimensao": "dimensions",
    "dimensoes": "dimensions",
    "medir": "ruler",
    "medida": "ruler",
    "regua": "ruler",
    "ferramenta": "wrench",
    "ferramentas": "wrench",
    "automacao": "robot",
    "robo": "robot",
    "exportar": "export",
    "importar": "import",
    "salvar": "save",
    "abrir": "folder-open",
    "novo": "plus",
    "criar": "plus-circle",
    "adicionar": "plus",
    "deletar": "trash",
    "excluir": "trash",
    "remover": "trash",
    "limpar": "eraser",
    "editar": "edit",
    "renomear": "edit",
    "copiar": "copy",
    "duplicar": "copy",
    "mover": "move",
    "rotacionar": "rotate-cw",
    "espelhar": "flip-horizontal",
    "filtrar": "filter",
    "buscar": "search",
    "pesquisar": "search",
    "selecionar": "mouse-pointer",
    "lista": "list",
    "listar": "list",
    "tabela": "table",
    "relatorio": "file-text",
    "report": "file-text",
    "grafico": "bar-chart",
    "estatistica": "bar-chart",
    "configurar": "settings",
    "configuracao": "settings",
    "ajustar": "settings",
    "ajuste": "settings",
    "verificar": "check-circle",
    "validar": "check-circle",
    "auditar": "shield-check",
    "consultar": "search",
    "ajuda": "help-circle",
    "informacao": "info",
    "info": "info",
    "alerta": "alert-triangle",
    "atencao": "alert-triangle",
    "erro": "x-circle",
    "sucesso": "check",
    # Documentacao / pranchas
    "prancha": "file",
    "pranchas": "files",
    "vista": "eye",
    "vistas": "eye",
    "view": "eye",
    "planta": "map",
    "plantas": "map",
    "corte": "scissors",
    "cortes": "scissors",
    "elevacao": "trending-up",
    "elevacoes": "trending-up",
    "perspectiva": "box",
    "secao": "scissors",
    # Familias e tipos
    "familia": "package",
    "familias": "package",
    "tipo": "tag",
    "tipos": "tag",
    "categoria": "folder",
    "categorias": "folder",
    "biblioteca": "library",
    "browser": "folder-tree",
    "navegador": "folder-tree",
    # Materiais
    "material": "palette",
    "materiais": "palette",
    "cor": "droplet",
    "cores": "droplet",
    "padrao": "grid-3x3",
    "padroes": "grid-3x3",
    "textura": "image",
    "texturas": "image",
    # Outros
    "luminaria": "lightbulb",
    "iluminacao": "lightbulb",
    "luz": "lightbulb",
    "hidraulica": "droplet",
    "tubulacao": "git-fork",
    "tubo": "git-fork",
    "conduite": "git-fork",
    "eletrica": "zap",
    "energia": "zap",
    "mep": "git-fork",
    "estrutura": "frame",
    "estrutural": "frame",
}


def fetch_url(url, timeout=15):
    """Faz GET HTTP simples e retorna bytes do response. Sem dependencias externas."""
    req = urllib.request.Request(url, headers={"User-Agent": "BIMCoder-ClaudeKit/0.1"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def translate_pt_to_en(query):
    """Traduz query em portugues para termos em ingles usando dicionario simples.

    Estrategia: divide a query em palavras, traduz cada uma, retorna a juncao.
    Palavras sem traducao ficam em pt mesmo (Iconify aceita).
    """
    words = query.lower().strip().split()
    translated = []
    for word in words:
        # Remove acentos basicos
        word_clean = word.replace("a", "a").replace("c", "c")  # placeholder
        translated.append(PT_TO_EN.get(word.lower(), word))
    return " ".join(translated)


def search_iconify(query):
    """Busca icones no Iconify e retorna lista de candidatos.

    Filtra resultados pelas bibliotecas preferidas.
    Retorna lista de {prefix, name, fullname} ranqueada.
    """
    en_query = translate_pt_to_en(query)
    encoded = urllib.parse.quote(en_query)
    url = f"https://api.iconify.design/search?query={encoded}&limit=50"

    try:
        raw = fetch_url(url)
        data = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        return []

    candidates = []
    for fullname in data.get("icons", []):
        if ":" not in fullname:
            continue
        prefix, name = fullname.split(":", 1)
        candidates.append({"prefix": prefix, "name": name, "fullname": fullname})

    # Rank: bibliotecas preferidas primeiro
    def rank_key(c):
        try:
            return PREFERRED_LIBS.index(c["prefix"])
        except ValueError:
            return len(PREFERRED_LIBS)  # nao preferida vai pro fim

    candidates.sort(key=rank_key)
    return candidates


def download_png(icon_fullname, output_path, color_hex):
    """Baixa PNG 96x96 do Iconify com cor especifica.

    icon_fullname: ex 'lucide:ruler'
    output_path: caminho completo do arquivo destino
    color_hex: ex '#344054' ou '%23344054' (url-encoded)
    """
    color = color_hex.lstrip("#")
    url = f"https://api.iconify.design/{icon_fullname}.png?height=96&color=%23{color}"

    try:
        png_bytes = fetch_url(url)
        # Validacao basica: PNGs comecam com magic bytes
        if not png_bytes.startswith(b"\x89PNG"):
            return False
        with open(output_path, "wb") as f:
            f.write(png_bytes)
        return True
    except Exception:
        return False


def is_explicit_icon_name(query):
    """Detecta se a query e nome explicito do Iconify (formato 'prefix:name')."""
    return ":" in query and " " not in query


def resolve_icon(query):
    """Resolve a query para um icon_fullname do Iconify.

    Se for nome explicito (lucide:ruler), retorna direto.
    Caso contrario, busca e retorna o primeiro candidato priorizado.
    """
    if is_explicit_icon_name(query):
        return query

    candidates = search_iconify(query)
    if not candidates:
        return None
    return candidates[0]["fullname"]


def main():
    if len(sys.argv) < 3:
        print(json.dumps({
            "success": False,
            "error": "Uso: icon-fetcher.py <query-pt-ou-nome-iconify> <pasta-destino>"
        }))
        sys.exit(1)

    query = sys.argv[1]
    output_dir = sys.argv[2]

    if not os.path.isdir(output_dir):
        print(json.dumps({
            "success": False,
            "error": f"Pasta destino nao existe: {output_dir}"
        }))
        sys.exit(1)

    icon_fullname = resolve_icon(query)
    if not icon_fullname:
        print(json.dumps({
            "success": False,
            "error": f"Nenhum icone encontrado para query: {query}"
        }))
        sys.exit(1)

    light_path = os.path.join(output_dir, "icon.png")
    dark_path = os.path.join(output_dir, "icon.dark.png")

    ok_light = download_png(icon_fullname, light_path, "#344054")
    ok_dark = download_png(icon_fullname, dark_path, "#FFFFFF")

    if not (ok_light and ok_dark):
        print(json.dumps({
            "success": False,
            "error": f"Falha ao baixar icone {icon_fullname}"
        }))
        sys.exit(1)

    print(json.dumps({
        "success": True,
        "icon_name": icon_fullname,
        "files": [light_path, dark_path]
    }))


if __name__ == "__main__":
    main()
