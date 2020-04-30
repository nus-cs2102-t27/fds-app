function getCookieValue(a) {
    var b = document.cookie.match('(^|[^;]+)\\s*' + a + '\\s*=\\s*([^;]+)');
    return b ? b.pop() : '';
}

function getAuth() {
    return JSON.parse(decodeURIComponent(getCookieValue("auth")));
}

