FROM nginx:stable-alpine

COPY ./docs /usr/share/nginx/html
COPY ./google_apps_script/ /usr/share/nginx/google_apps_script/
