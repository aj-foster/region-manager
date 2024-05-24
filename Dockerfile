FROM hexpm/erlang:26.2.2-debian-bookworm-20240130-slim

ENV LC_ALL C.UTF-8
WORKDIR /srv

RUN addgroup erlang && \
    adduser \
        --home /srv \
        --ingroup erlang \
        --disabled-password \
        --no-create-home \
        erlang && \
    chown -R erlang:erlang /srv

ADD export/*.tar.gz /srv/
RUN chown -R erlang:erlang /srv

USER erlang
ENTRYPOINT [ "/srv/bin/server" ]
