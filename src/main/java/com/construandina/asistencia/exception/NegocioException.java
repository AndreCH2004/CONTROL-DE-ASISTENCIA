package com.construandina.asistencia.exception;

import org.springframework.http.HttpStatus;

/** Error esperado de una regla de negocio; el mensaje sí se muestra al cliente. */
public class NegocioException extends RuntimeException {

    private final HttpStatus status;

    public NegocioException(HttpStatus status, String mensaje) {
        super(mensaje);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
