# ==============================================================================
# ESTÁGIO 1: Builder (Compilação e preparação de dependências)
# ==============================================================================
FROM python:3.11-slim AS builder

# Evita que o Python grave arquivos .pyc no disco e buferize o stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Instala pacotes necessários para compilar dependências (se houver) e limpa o cache do apt
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Cria um ambiente virtual (venv) isolado para a aplicação
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Atualiza o pip e instala as dependências diretamente no ambiente virtual
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir fastapi uvicorn

# ==============================================================================
# ESTÁGIO 2: Runner (Imagem final de execução - ultra leve e segura)
# ==============================================================================
FROM python:3.11-slim AS runner

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Garante que os binários do ambiente virtual copiado sejam priorizados no PATH
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Copia apenas as dependências pré-instaladas do estágio Builder
COPY --from=builder /opt/venv /opt/venv

# Cria um usuário e grupo não-root para segurança (Princípio do Menor Privilégio)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/bash -m appuser

# Copia o código da aplicação definindo o proprietário como o usuário não-root
COPY --chown=appuser:appgroup main.py /app/main.py

# Altera o contexto de execução para o usuário não-root
USER appuser

# Porta interna que o FastAPI utilizará
EXPOSE 8000

# HEALTHCHECK inteligente: utiliza o interpretador Python nativo para validar o status da API.
# Evita a necessidade de instalar curl ou wget na imagem final (reduzindo a superfície de ataque).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/').getcode()" || exit 1

# Comando de inicialização do Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]