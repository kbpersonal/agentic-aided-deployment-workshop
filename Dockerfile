FROM golang:1.27.2-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /workshop-app .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /workshop-app /workshop-app
ENV HOST=0.0.0.0 PORT=3000
EXPOSE 3000
ENTRYPOINT ["/workshop-app"]
