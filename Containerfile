FROM quay.io/fedora/fedora-silverblue:latest

COPY packages /packages
RUN rpm-ostree install /packages/*.rpm powertop && \
    rm -rf /packages && \
    rpm-ostree cleanup -m
