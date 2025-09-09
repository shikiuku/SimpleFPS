# Railway用Godotサーバー
FROM ubuntu:22.04

# パッケージリストを更新し、必要なパッケージをインストール
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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

# ポートを公開
EXPOSE $PORT

# サーバーを起動（プロジェクトファイルを直接実行）
CMD ["/usr/local/bin/godot", "--headless", "--main-pack", "."]