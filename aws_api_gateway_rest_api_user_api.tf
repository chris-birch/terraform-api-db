#
# REST API used by end users to access app data
# 
# Secured by an API key
#

resource "aws_api_gateway_rest_api" "user_api" {
  name = "${var.project}_user_api_${random_id.generator.id}"
}

resource "aws_api_gateway_resource" "book_id" {
  parent_id   = aws_api_gateway_rest_api.user_api.root_resource_id
  path_part   = "{book_id}"
  rest_api_id = aws_api_gateway_rest_api.user_api.id
}

resource "aws_api_gateway_method" "get" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.book_id.id
  rest_api_id   = aws_api_gateway_rest_api.user_api.id
}

# Create an integration with the dynamo db
resource "aws_api_gateway_integration" "books_table_integration" {
  rest_api_id = aws_api_gateway_rest_api.user_api.id
  resource_id = aws_api_gateway_resource.book_id.id
  http_method = aws_api_gateway_method.get.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:dynamodb:action/Query"
  credentials             = aws_iam_role.default_user_api_role.arn
  request_templates = {
    "application/json" = <<EOF
      {
        "TableName": "${aws_dynamodb_table.books_table.name}",
        "KeyConditionExpression": "pk = :val",
        "ExpressionAttributeValues": {
          ":val": {
              "S": "$input.params('book_id')"
          }
        }
      }
    EOF
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.user_api.id
  resource_id = aws_api_gateway_resource.book_id.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "books_table_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.user_api.id
  resource_id = aws_api_gateway_resource.book_id.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_templates = {
    "application/json" = <<EOF
      #set($inputRoot = $input.path('$'))
      {
        #foreach($elem in $inputRoot.Items)
        "id": "$elem.pk.S",
        "message": "$elem.hello.S",
        #if($foreach.hasNext),#end
        #end
      }
    EOF
  }
}

resource "aws_api_gateway_deployment" "user_api" {
  rest_api_id = aws_api_gateway_rest_api.user_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.book_id,
      aws_api_gateway_method.get,
      aws_api_gateway_integration.books_table_integration,
      aws_api_gateway_integration_response.books_table_integration_response,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "user_api_prod" {
  deployment_id = aws_api_gateway_deployment.user_api.id
  rest_api_id   = aws_api_gateway_rest_api.user_api.id
  stage_name    = "prod"
}


#
## Roles & Policy's ##
#

# The policy document to access the role
data "aws_iam_policy_document" "query_books_table" {
  depends_on = [aws_dynamodb_table.books_table]
  statement {
    sid = "querybookstable"

    actions = [
      "dynamodb:Query"
    ]

    resources = [
      aws_dynamodb_table.books_table.arn,
    ]
  }
}

# The IAM Role for the execution
resource "aws_iam_role" "default_user_api_role" {
  name               = "default_user_api_role"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "apigateway.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": "iamroletrustpolicy"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "books_table" {
  name = "userapi-books-table"
  role = aws_iam_role.default_user_api_role.id
  policy = data.aws_iam_policy_document.query_books_table.json
}