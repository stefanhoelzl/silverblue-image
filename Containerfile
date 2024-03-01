FROM quay.io/fedora/fedora-silverblue:39

RUN rpm-ostree cliwrap install-to-root / && \
    # install additional packages
    rpm-ostree install \
        mozilla-openh264 && \
    rpm-ostree cleanup -m && \
    ostree container commit
