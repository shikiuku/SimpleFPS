# Railway用Godotサーバー
FROM alpine:latest

# 必要なパッケージをインストール
RUN apk add --no-cache \
    wget \
    unzip \
    ca-certificates

# Godot Headless バイナリをダウンロード
RUN wget -q https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip \
    && unzip Godot_v4.4.1-stable_linux.x86_64.zip \
    && mv Godot_v4.4.1-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm Godot_v4.4.1-stable_linux.x86_64.zip

# 作業ディレクトリを設定
WORKDIR /app

# プロジェクトファイルをコピー
COPY . .

# エクスポート用テンプレートは不要（ヘッドレスサーバーのため）

# ポートを公開
EXPOSE 7000

# サーバーを起動
CMD ["/usr/local/bin/godot", "--headless", "--main-pack", "server.pck"]