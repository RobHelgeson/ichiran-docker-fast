FROM ubuntu

ARG DEBIAN_FRONTEND=noninteractive
ENV PGPASSWORD=postgres

# Update packages
RUN apt update; apt dist-upgrade -y

# Install packages (no Node.js needed)
RUN apt install -y \
  postgresql \
  sudo \
  locales \
  wget \
  sbcl \
  git \
  gnupg \
  curl

# Download database and quicklisp libraries, and jmdict dictionary
RUN wget https://github.com/tshatrov/ichiran/releases/download/ichiran-230122/ichiran-230122.pgdump
RUN wget https://beta.quicklisp.org/quicklisp.lisp
RUN wget https://beta.quicklisp.org/quicklisp.lisp.asc
RUN git clone https://gitlab.com/yamagoya/jmdictdb.git

# Add sudo users user 'postgres'
RUN adduser postgres sudo

# Set japanese locale
RUN localedef -i ja_JP -c -f UTF-8 -A /usr/share/locale/locale.alias ja_JP.UTF-8

# Install quicklisp
RUN gpg --verify /quicklisp.lisp.asc /quicklisp.lisp; exit 0
RUN sbcl --load /quicklisp.lisp --eval '(quicklisp-quickstart:install)' --eval '(ql:add-to-init-file)' --eval '(sb-ext:quit)'

# Download ichiran
RUN cd /root/quicklisp/local-projects/ && git clone https://github.com/tshatrov/ichiran.git

# Copy settings
COPY ./settings.lisp /root/quicklisp/local-projects/ichiran/settings.lisp

# Copy server files into ichiran's local-projects directory
COPY ./ichiran-server.asd /root/quicklisp/local-projects/ichiran/ichiran-server.asd
COPY ./server.lisp /root/quicklisp/local-projects/ichiran/server.lisp

# Run postgresql server, create database, load database dump, and verify ichiran works
RUN service postgresql start && \
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';" && \
  sudo -u postgres createdb -E 'UTF8' -l 'ja_JP.utf8' -T template0 ichiran-db && \
  sudo -u postgres pg_restore -c -d ichiran-db ichiran-230122.pgdump --no-owner --no-privileges || true && \
  sbcl --eval '(load "~/quicklisp/setup.lisp")' --eval '(ql:quickload :ichiran)' --eval '(ichiran/mnt:add-errata)' --eval '(ichiran/test:run-all-tests)' --eval '(sb-ext:quit)' && \
  sbcl --eval '(load "~/quicklisp/setup.lisp")' --eval '(ql:quickload :ichiran-server)' --eval '(sb-ext:quit)' && \
  service postgresql stop

# Build ichiran-cli too (useful for debugging)
RUN service postgresql start && \
  sbcl --eval '(load "~/quicklisp/setup.lisp")' --eval '(ql:quickload :ichiran/cli)' --eval '(ichiran/cli:build)' && \
  /root/quicklisp/local-projects/ichiran/ichiran-cli "一覧は最高だぞ" && \
  service postgresql stop

COPY ./start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
