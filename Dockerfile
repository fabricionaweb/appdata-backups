FROM alpine

RUN apk --no-cache add curl file
RUN curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s

WORKDIR /root/.google-drive-upload/bin
ENTRYPOINT [ "sh", "gupload" ]
