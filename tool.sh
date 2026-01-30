#!/bin/bash

# ==========================================
#  MODIFIED CONFIGURATION (Playit.gg)
# ==========================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GOPATH="$BASE_DIR/go"
export PATH="$BASE_DIR/bin:$BASE_DIR/go/bin:$PATH"

# --- ZOMBIE KILLER FUNCTION ---
kill_zombies() {
    TARGET=$1
    echo "   -> Hunting for '$TARGET'..."
    if command -v pidof &> /dev/null; then
        PIDS=$(pidof $TARGET)
        if [ ! -z "$PIDS" ]; then
            kill -9 $PIDS 2>/dev/null
            echo "      Killed via pidof."
            return
        fi
    fi
}

echo ">>> [1/6] Cleaning up Zombies..."
rm -f playit.log bot.log
kill_zombies "playit"
kill_zombies "fsb"

echo ">>> [2/6] Environment Check & Install Playit..."
# ১. Go চেক
if ! command -v go &> /dev/null; then
    if [ ! -d "$BASE_DIR/go" ]; then
        echo ">>> Downloading Go..."
        curl -L -o go.tar.gz --doh-url https://1.1.1.1/dns-query "https://go.dev/dl/go1.21.6.linux-amd64.tar.gz"
        tar -xzf go.tar.gz
        rm go.tar.gz
    fi
fi

# ২. Playit ইন্সটল
if ! command -v playit &> /dev/null; then
    echo ">>> Installing Playit..."
    curl -SsL https://playit-cloud.github.io/ppa/key.gpg | sudo apt-key add -
    sudo curl -SsL -o /etc/apt/sources.list.d/playit-cloud.list https://playit-cloud.github.io/ppa/playit-cloud.list
    sudo apt-get update
    sudo apt-get install playit -y
fi

echo ">>> [3/6] Starting Playit Tunnel..."
# সিক্রেট দিয়ে রান করা
nohup playit --secret $PLAYIT_SECRET > playit.log 2>&1 &
echo "⏳ Playit Starting... Waiting 10s..."
sleep 10

# আপনার ফিক্সড লিংক ব্যবহার করা (GitHub Secret থেকে আসবে)
CF_URL="$PLAYIT_URL"
echo "🔗 Using Fixed URL: $CF_URL"

echo ">>> [4/6] Updating Worker..."
UPDATE_RES=$(curl -s -4 -L --doh-url https://1.1.1.1/dns-query --retry 3 "$WORKER_URL?key=$WORKER_KEY&update=$CF_URL")
echo "Worker Update Response: $UPDATE_RES"

echo ">>> [5/6] Setting up Bot..."
if [ ! -d "TG-FileStreamBot" ]; then
    echo "Cloning Bot Repo..."
    git clone https://github.com/affaz101/TG-FileStream
fi

cd TG-FileStream || exit 1

# বিল্ড করা (আপনার অরিজিনাল লজিক - fsb ফাইল অটো তৈরি হবে)
if [ ! -f "fsb" ]; then
    echo "Building Bot Binary..."
    export GOCACHE="$BASE_DIR/go/cache"
    CGO_ENABLED=0 go build -o fsb -ldflags="-w -s" ./cmd/fsb
fi

echo ">>> [6/6] Fetching Secrets & Running..."
SECRETS_JSON=$(curl -s -4 -L --doh-url https://1.1.1.1/dns-query \
    -H "User-Agent: curl/7.68.0" \
    --retry 3 \
    "$WORKER_URL?key=$WORKER_KEY")

if [[ -z "$SECRETS_JSON" ]] || [[ "$SECRETS_JSON" != *"API_ID"* ]]; then
    echo "❌ Error: Failed to fetch secrets from Worker."
    exit 1
fi

export API_ID=$(echo "$SECRETS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['API_ID'])")
export API_HASH=$(echo "$SECRETS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['API_HASH'])")
export BOT_TOKEN=$(echo "$SECRETS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['BOT_TOKEN'])")
export LOG_CHANNEL=$(echo "$SECRETS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['LOG_CHANNEL'])")

# সেশন ক্লিনআপ
export USE_SESSION_FILE=false
rm -f fsb.session
rm -rf sessions

export PORT=8080
export HOST="$CF_URL"

echo "🚀 Launching Bot..."
./fsb run
