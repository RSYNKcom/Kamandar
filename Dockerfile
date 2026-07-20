# Runs kamandar's built-in web UI (`--serve`) in a container, for serving behind
# a reverse proxy (e.g. roost). Stdlib-only Ruby, no gems to install.
# Requires GITHUB_TOKEN + GH_LOGIN at runtime; KAMANDAR_HOST=0.0.0.0 makes the
# server bind all interfaces so the proxy can reach it.
FROM ruby:3.4-slim
WORKDIR /app
COPY . .
ENV KAMANDAR_HOST=0.0.0.0
EXPOSE 4567
# --no-open: don't try to launch a desktop browser inside the container.
CMD ["ruby", "lib/kamandar.rb", "--serve", "--no-open"]
