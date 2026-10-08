# Class competition

Students log in to the game with a class code, their number and a PIN. While they
play, the game reports their progress to a small classroom server, and two live pages
show the whole class on the projector:

- **Scoreboard** (`/class/board.html?c=CODE`): every student's rank, score, progress
  through the 13 story milestones, quiz stars, words and play time.
- **Mira's Status Board** (`/class/mira.html?c=CODE`): one card per student. "Minji's Mira"
  shows the tumor size, Mira's strength and immune readiness. The tumor grows while the
  student plays until their Knights reach it, then shrinks live as they kill tumor cells,
  until remission.

How scores and Mira's status are computed is in [API.md](API.md).

## Running a lesson

1. Open `/class/teacher.html`, enter the teacher password, create a class (e.g. `BIO-2A`)
   and paste the student names, one per line.
2. Print the login cards (each has the class code, student number, name and PIN).
3. Students open the game, press **Class Login** on the title screen and enter their card.
   They stay logged in on that device until they press **Log out**.
4. Put the Scoreboard or the Mira board on the projector.
5. For a new round, press **Reset all progress** on the teacher page (logins stay).

Only **New Game** and **Continue** count. **Chapter Select** and debug mode (F2) are
practice: the HUD shows "Practice (not counted)" and nothing is sent. Starting a New Game
never loses points, and replaying content never adds points: the server keeps each
student's best.

## Deploying next to the game (prince.aiedus.org)

The server is a single file with no dependencies (Node 18+). It listens on 127.0.0.1:8110,
and nginx forwards `/api/` and `/class/` to it, so the web game reaches it on its own origin.

```bash
# 1. a service that survives reboots
sudo tee /etc/systemd/system/prince-classroom.service <<'EOF'
[Unit]
Description=Prince of mRNA classroom server
After=network.target

[Service]
WorkingDirectory=/home/jit/mRNA
ExecStart=/usr/bin/node classroom/server.js
Environment=PORT=8110
Environment=TEACHER_PASSWORD=change-me
Restart=always
User=jit

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now prince-classroom
```

```nginx
# 2. inside the server { } blocks of /etc/nginx/sites-available/prince.aiedus.org
location /api/ {
    proxy_pass http://127.0.0.1:8110;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_buffering off;            # live updates (Server-Sent Events)
    proxy_read_timeout 1h;
}
location /class/ {
    proxy_pass http://127.0.0.1:8110;
    proxy_set_header Host $host;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Then rebuild and deploy the web game as usual (`./deploy.sh`). Cloudflare: make sure
`/api/*` is not cached (it sends `Cache-Control: no-store`, which Cloudflare respects by
default).

Data lives in `classroom/data/classroom.json` (not in git). Back it up if you want to keep
results. PINs are stored in plain text so the teacher page can reprint cards; they only
protect a game score.

## Testing locally

```bash
TEACHER_PASSWORD=test PORT=8110 node classroom/server.js
# desktop game against the local server:
godot --path . -- api=http://127.0.0.1:8110
```

Pages: http://127.0.0.1:8110/class/. Add `&demo=1` to the board URLs to see them with fake
students and no server data.
