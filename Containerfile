FROM quay.io/fedora/fedora-silverblue:latest

COPY packages /packages
RUN rpm-ostree cliwrap install-to-root / && \
    rpm-ostree override remove noopenh264 && \
    # upgrade to kernel 6.12 to avoid amdgpu bug
    rpm-ostree override replace /packages/kernel/*.rpm && \
    # install additional packages
    rpm-ostree install \
        /packages/*.rpm \
        powertop openh264 mozilla-openh264  && \
    rm -rf /packages && \
    rpm-ostree cleanup -m
