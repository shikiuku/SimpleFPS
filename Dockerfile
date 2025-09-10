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

# サーバーバイナリに実行権限を付与
RUN chmod +x "Simple FPS.x86_64"

# ポートを公開
EXPOSE $PORT

# エクスポート済みサーバーを起動
CMD ["./Simple FPS.x86_64", "--headless"]