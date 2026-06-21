# Lightweight static server for the AverageTouchTool landing page (web/).
# Only the web/ folder + nginx.conf are sent as build context (see .dockerignore).
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY web/ /usr/share/nginx/html/

EXPOSE 80
