FROM golang:1.20-alpine3.16 AS builder

WORKDIR /opt

RUN apk add --update curl make git libc-dev bash gcc linux-headers eudev-dev python3

# Copy the remaining files
COPY . .

RUN make install

FROM alpine:3.16
COPY --from=builder /go/bin/simd /usr/local/bin/
RUN apk add bash vim \
    && addgroup -g 1000 simd \
    && adduser -S -h /home/simd -D simd -u 1000 -G simd

USER 1000
WORKDIR /home/simd

EXPOSE 26657 26656 1317 9090

CMD ["simd", "start"]
