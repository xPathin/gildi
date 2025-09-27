FROM node:lts-alpine
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY ["package.json", "pnpm-lock.yaml*", "npm-shrinkwrap.json*", "./"]
# install pnpm
RUN ["npm", "install", "-g", "pnpm"]
RUN pnpm install --prod
COPY . .
RUN chown -R node /usr/src/app
USER node
RUN ["pnpm", "run", "build"]
CMD ["pnpm", "start"]
