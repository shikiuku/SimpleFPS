# Railway用Godot専用サーバー
FROM ubuntu:22.04

# 必要なライブラリをインストール
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libfontconfig1 \
    libfreetype6 \
    libgl1-mesa-glx \
    libasound2 \
    libpulse0 \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /app

# エクスポート済みサーバーファイルをコピー
COPY build/Simple* ./

# サーバーバイナリをリネームして実行権限を付与
RUN mv "Simple FPS.x86_64" simple-fps-server && \
    mv "Simple FPS.pck" simple-fps-server.pck && \
    chmod +x simple-fps-server

# ポートを公開
EXPOSE $PORT

# エクスポート済みサーバーを起動（ServerMainシーンを直接実行）
CMD ["./simple-fps-server", "--headless", "--main-pack", "simple-fps-server.pck", "res://scenes/ServerMain.tscn"]