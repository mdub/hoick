# Hoick

Hoick is a command-line HTTP client.  It's intended mainly as a tool for testing RESTful APIs, but you can use for something else, if you really want to.

Hoick is designed to be simple yet useful, and to play nicely in a Unix command pipeline.

## Installation

Hoick is distributed as a Ruby gem, installable using:

    $ gem install hoick

## Usage

Hoick has subcommands modelled on HTTP verbs.

### GET

To fetch a resource, use GET.  The response body will be printed to STDOUT.

    $ hoick GET http://api.example.com/widgets/123

If you're interested in response headers too, add the "`-h`" flag.  Add the "`--follow`" flag if you wish to follow redirects.

### PUT and POST

The "PUT" subcommand uploads data to a specified URL.

    $ hoick PUT -T json http://api.example.com/widgets/123 < widget-123.json

By default, the payload is read from STDIN, but you can specify the "`-F`" option to read it from a file, instead.

    $ hoick PUT -F widget-123.json http://api.example.com/widgets/123

Hoick guesses a "Content-Type" from the file-name.  If a type cannot be guessed, or if the payload is sourced from STDIN, binary data ("application/octet-stream") is assumed.  Either way, the default can be overridden with "`-T`" (which can be either a file extension, or a full MIME-type string).

The "POST" subcommand works in a similar way.

### HEAD and DELETE

Rounding out the RESTful actions, "HEAD" and "DELETE" do pretty much what you'd expect.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Submit a Pull Request
