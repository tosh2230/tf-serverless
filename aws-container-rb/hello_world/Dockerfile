FROM ruby:2.7-slim

ARG FUNCTION_DIR="./"
COPY app.rb Gemfile ${FUNCTION_DIR}
RUN bundle install

WORKDIR ${FUNCTION_DIR}
ENTRYPOINT ["/usr/local/bundle/bin/aws_lambda_ric"]

# Command can be overwritten by providing a different command in the template directly.
CMD ["app.lambda_handler"]
