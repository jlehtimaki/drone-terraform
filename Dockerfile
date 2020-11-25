FROM golang:1.15-alpine AS builder

# RUN apk add --no-cache git

WORKDIR /tmp/drone-terraform

COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -tags netgo -o /go/bin/drone-terraform

FROM ubuntu:20.04 as executables

RUN apt update && apt install wget curl unzip gettext-base -y

WORKDIR /execs
RUN wget -q https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip -O terraform.zip && \
  unzip terraform.zip
RUN wget -q https://storage.googleapis.com/kubernetes-release/release/v1.18.10/bin/linux/amd64/kubectl && \
chmod +x kubectl
RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.9/2020-01-22/bin/linux/amd64/aws-iam-authenticator && \
chmod +x aws-iam-authenticator
RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip && unzip awscliv2.zip

FROM ubuntu:20.04

# Install required packages
RUN apt update && apt install -y less ca-certificates openssl openssh-client git

# Install AWSCLI
COPY --from=executables /execs/aws .
RUN ./install -b /bin

# Copy executables
COPY --from=builder /go/bin/drone-terraform /bin/
COPY --from=executables /execs/terraform /bin/
COPY --from=executables /execs/kubectl /bin/
COPY --from=executables /execs/aws-iam-authenticator /bin/

ENTRYPOINT ["/bin/drone-terraform"]
