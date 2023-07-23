# Fetch

Fetch is a HTTP/0.9 server and proxy to other protocols

## Protocols

- Gemini
- Gopher
- HTTP
- HTTPS

## Usage

Run the `fetchd` daemon:

    $ ruby fetchd.rb --server --proxy

Send a HTTP server request to the daemon:

    $ echo "GET /README.md" | nc localhost 8888
    # Fetch

    Fetch is a HTTP/0.9 server and proxy to other protocols

Send a HTTPS proxy request to the daemon:

    $ echo "GET https://example.com" | nc localhost 8888
    <!doctype html>
    <html>
    ...
    </html>

Send a Gemini proxy request to the daemon:

    $ echo "GET gemini://gemini.circumlunar.space" | nc localhost 8888
    # Project Gemini

    ## Gemini in 100 words

    Gemini is a new internet technology supporting an electronic library of
    interconnected text documents.
    ...

## License

Fetch is released under MIT
