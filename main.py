#!/usr/bin/env python3

import jinja2

if __name__ == "__main__":
    env = jinja2.Environment(
        loader = jinja2.PackageLoader(__name__, "templates"),
    )

    hello_template = env.get_template("hello.lds")

    print(hello_template.render(test=42))

