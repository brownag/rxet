/*
 * Custom R connection that reads a Xet file on demand.
 *
 * R has no R-level API for new connection types, so the read/seek/close
 * callbacks live here. Each read is forwarded to an R closure that calls back
 * into Rust (`rxet_reader_read()`), which serves the bytes from a Xet download
 * stream group with a readahead window.
 *
 * The package requires R >= 4.3.0, where R_new_custom_connection() appeared.
 */

#include <R.h>
#include <Rinternals.h>
#include <string.h>
#include <stdlib.h>

#include <R_ext/Connections.h>

typedef struct {
    SEXP read_fun; /* function(offset, length) -> raw, preserved */
    SEXP close_fun; /* function() releasing the reader, preserved */
    double size;   /* file size in bytes */
    double pos;    /* current read position, 0-based */
    int closed;
} rxet_conn_state;

static size_t rxet_conn_read(void *ptr, size_t size, size_t nitems, Rconnection con) {
    rxet_conn_state *st = (rxet_conn_state *) con->private;
    size_t total = size * nitems;

    if (st == NULL || st->closed || size == 0 || total == 0) return 0;
    if (st->pos >= st->size) return 0;

    /* A short read at the end of the file is fine; readBin() reports it. */
    if ((double) total > st->size - st->pos) total = (size_t) (st->size - st->pos);
    total -= total % size;
    if (total == 0) return 0;

    SEXP s_pos = PROTECT(Rf_ScalarReal(st->pos));
    SEXP s_total = PROTECT(Rf_ScalarReal((double) total));
    SEXP call = PROTECT(Rf_lang3(st->read_fun, s_pos, s_total));
    SEXP res = PROTECT(Rf_eval(call, R_GlobalEnv));

    if (TYPEOF(res) != RAWSXP || (size_t) XLENGTH(res) != total) {
        UNPROTECT(4);
        Rf_error("Xet connection read failed: expected %zu raw bytes", total);
    }

    memcpy(ptr, RAW(res), total);
    st->pos += (double) total;
    UNPROTECT(4);

    return total / size;
}

/* seek(con, where, origin, rw): origin 1 = start, 2 = current, 3 = end.
 * rw 0 = both, 1 = read, 2 = write. `where` NA means "tell". */
static double rxet_conn_seek(Rconnection con, double where, int origin, int rw) {
    rxet_conn_state *st = (rxet_conn_state *) con->private;
    double base;

    if (st == NULL) Rf_error("Xet connection is closed");
    if (ISNA(where)) return st->pos;

    double previous = st->pos;

    switch (origin) {
    case 2: base = st->pos; break;
    case 3: base = st->size; break;
    default: base = 0.0; break;
    }

    double target = base + where;
    if (!R_FINITE(target) || target < 0.0 || target > st->size) {
        Rf_error("Xet connection seek is outside the file (0 to %.0f)", st->size);
    }
    st->pos = target;
    return previous;
}

static void rxet_conn_close(Rconnection con) {
    rxet_conn_state *st = (rxet_conn_state *) con->private;
    if (st == NULL || st->closed) return;
    st->closed = 1;
    SEXP call = PROTECT(Rf_lang1(st->close_fun));
    Rf_eval(call, R_GlobalEnv);
    UNPROTECT(1);
}

/* Called exactly once, from close() or from the connection finalizer. */
static void rxet_conn_destroy(Rconnection con) {
    rxet_conn_state *st = (rxet_conn_state *) con->private;
    if (st == NULL) return;
    con->private = NULL;
    if (st->read_fun != R_NilValue) R_ReleaseObject(st->read_fun);
    if (st->close_fun != R_NilValue) R_ReleaseObject(st->close_fun);
    free(st);
}

/* Builds the connection. Called from Rust, which has no registration table
 * entry of its own to spare, so this stays a plain C function. */
SEXP rxet_connection_new(SEXP read_fun, SEXP close_fun, double size) {
    Rconnection con = NULL;
    rxet_conn_state *st = (rxet_conn_state *) calloc(1, sizeof(rxet_conn_state));
    if (st == NULL) Rf_error("cannot allocate a Xet connection");

    SEXP con_sexp = PROTECT(R_new_custom_connection("Xet file", "rb", "rxet_connection", &con));

    st->read_fun = read_fun;
    st->close_fun = close_fun;
    st->size = size;
    st->pos = 0.0;
    st->closed = 0;
    R_PreserveObject(st->read_fun);
    R_PreserveObject(st->close_fun);

    /* Binary, readable, seekable: arrow() wraps this as a RandomAccessFile. */
    con->text = FALSE;
    con->isopen = TRUE;
    con->blocking = TRUE;
    con->canread = TRUE;
    con->canwrite = FALSE;
    con->canseek = TRUE;
    con->private = st;
    con->read = rxet_conn_read;
    con->seek = rxet_conn_seek;
    con->close = rxet_conn_close;
    con->destroy = rxet_conn_destroy;

    UNPROTECT(1);
    return con_sexp;
}
