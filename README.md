PDFMaker Service
==

This micro service gets either HTML content or an URL and converts it to a PDF.

You need to do a post request with a token (specified in .env - generated when you first start the service) and either an `url` or a `html` POST parameter.

Requirements
--
1. Docker and docker-compose
2. bash

Start
--

To start the app just execute `./app up -d` - You will be asked to specify the HTTP port your app will bind to as well as a token. You can keep the defaults.. but.. not really recommended.

Example usage
==
I. Get a PDF from an URL
--
This is a curl example. Please update your token, url and port if required.
```
curl -v http://localhost:8111/ \
   -H "Content-type: application/x-www-form-urlencoded" \
   -H "Token: ChangeMePlease" \
   -d "url=https://www.google.com" \
   -o test.pdf
```

II. Generate PDF from HTML
--
This example is a bit tricky to run, but hopefully you get the gist
```
export yourHtml=$(cat << yourHTML 
<html>
            <head>
              <link rel="stylesheet"
                    href="https://fonts.googleapis.com/css?family=Tangerine">
              <style>
                body {
                  font-family: 'Tangerine', serif;
                  font-size: 48px;
                }
              </style>
            </head>
            <body>
              <div>Yas\! PDF With Webfonts\!</div>
            </body>
          </html>
yourHTML
)

curl -v http://localhost:8111/ \
	-H "Content-type: application/x-www-form-urlencoded" \
	-H "Token: ChangeMePlease" \
	-d "html=$yourHtml" \
	-o test2.pdf
```

III. Append & Prepend
--
Here is some magic, using the `pre` and `post` parameters you can provide other PDFs to merge by providing their link. Since the path is relative to the container in this example you wil; see `http://web` but remember, this can be any valid URL of a PDF.
```
curl -v http://localhost:8111/ \
	-H "Content-type: application/x-www-form-urlencoded" \
	-H "Token: ChangeMePlease" \
	-d "html=This is a simple test" \
	-d "pre=http://web/examples/pre.pdf" \
	-d "post=http://web/examples/post.pdf,http://web/examples/post2.pdf" \
	-o test.pdf
```

Future releases
==
1. Will add custom compression. Check https://gist.github.com/firstdoit/6390547 for more info
2. Will create a composer package to streamline the usage of this service 
3. Will remove the docker-compose dependency so it will run only with docker