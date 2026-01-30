///|
test "reason_for_status common codes" {
  inspect(reason_for_status(200), content="OK")
  inspect(reason_for_status(201), content="Created")
  inspect(reason_for_status(204), content="No Content")
  inspect(reason_for_status(301), content="Moved Permanently")
  inspect(reason_for_status(302), content="Found")
  inspect(reason_for_status(304), content="Not Modified")
  inspect(reason_for_status(400), content="Bad Request")
  inspect(reason_for_status(401), content="Unauthorized")
  inspect(reason_for_status(403), content="Forbidden")
  inspect(reason_for_status(404), content="Not Found")
  inspect(reason_for_status(405), content="Method Not Allowed")
  inspect(reason_for_status(500), content="Internal Server Error")
  inspect(reason_for_status(502), content="Bad Gateway")
  inspect(reason_for_status(503), content="Service Unavailable")
}

///|
test "reason_for_status unknown" {
  inspect(reason_for_status(418), content="Unknown")
}
