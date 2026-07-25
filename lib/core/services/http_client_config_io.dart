import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

// Certificado autoassinado do servidor BabyBox (LAN interna, sem domínio
// público, então não dá pra emitir certificado via CA pública tipo Let's
// Encrypt). SAN: IP Address:192.168.18.152 — válido até 2036-04-14.
//
// Em vez de desativar a validação de certificado (badCertificateCallback
// sempre true, o que abriria a porta pra MITM em qualquer host), confiamos
// *apenas* nesse certificado específico via SecurityContext isolado.
const _pinnedServerCertPem = '''
-----BEGIN CERTIFICATE-----
MIIDqjCCApKgAwIBAgIUVa0BCQ8DpsjLu5rw+IlE/NZgvwYwDQYJKoZIhvcNAQEL
BQAwXDELMAkGA1UEBhMCQlIxCzAJBgNVBAgMAlNQMREwDwYDVQQHDAhTYW9QYXVs
bzEUMBIGA1UECgwLVU5JUC1QT1JUQUwxFzAVBgNVBAMMDjE5Mi4xNjguMTguMTUy
MB4XDTI2MDQxNzAxMTcxN1oXDTM2MDQxNDAxMTcxN1owXDELMAkGA1UEBhMCQlIx
CzAJBgNVBAgMAlNQMREwDwYDVQQHDAhTYW9QYXVsbzEUMBIGA1UECgwLVU5JUC1Q
T1JUQUwxFzAVBgNVBAMMDjE5Mi4xNjguMTguMTUyMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEArEbxDrh5dLsGIehN99+dS2iwytlpMYJ296MWvIIdqQkn
VG1CBrrtVB4jpexvkL2pqPSHHCwla87D/7wEzrJnEVufel/V/LC3bW3Dc7eLQQ8x
0n1JHROAbxUWJpBQEpdZIUf83EhfQ3QA3Z3mJAyE23R06CQN7EXJwzrCTWRt+3+d
C2VfTWAoRFI7gGDFybkoPGM7Vj3d/bTYX6DUhZW8hm4kBVxMoVeL2vsFx+xM0Psq
ecjcYC5U43K6uhrow5Y4v5aE8nyQMiXySSJdNCRdE3SQAGEfriBbJh2nZUz+q38d
uIoQOHUBJEFeSQBEpEwlfxUlNnE1ihtxfrSQRPCEYQIDAQABo2QwYjAdBgNVHQ4E
FgQU+LK7FogeGy59Ukbe9+dnANqOW6YwHwYDVR0jBBgwFoAU+LK7FogeGy59Ukbe
9+dnANqOW6YwDwYDVR0TAQH/BAUwAwEB/zAPBgNVHREECDAGhwTAqBKYMA0GCSqG
SIb3DQEBCwUAA4IBAQAskSj0rsCl2yQPLGt0jkxngkFPI2yjaWullRNIP0/lbauh
X/LDIUZvnLq/zJsjSb3+9n5KXlyrRYX4DDPzu7bVKZi5LR+wxxqkDN1qHDymQ+vf
oApKLiJjp/2I//kQYaMy1/mtg1eB7fUoU7ScJ+FEkoupUfGlL/nkeg5cur3ULxtS
Iz+V9unKZQng3w/N71Gd+i+be8ZTqYdIjM2ZxA5QEHJy1kRdTMr9DuPc7ybVqNul
TzVR7lZZnnCzmVRCs66uNSWnFRw+ysATYnB5SwfaWn7xfEdC9K0GoulwzHUjbxwL
gZx3SReBa/idHST71lpFImc1VFZbeaU4BQ6XmY0Q
-----END CERTIFICATE-----
''';

void configureHttpClient(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;

  adapter.createHttpClient = () {
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(_pinnedServerCertPem));
    return HttpClient(context: context);
  };
}
