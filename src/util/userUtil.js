function getRedirectionForUserType(userType) {
    switch (userType) {
        case "customer":
            return "/app/customer.html"
        case "staff":
            return "/app/staff.html"
        case "manager":
            return "/app/manager.html"
        case "ptrider":
            return "/app/ptrider.html"
        case "ftrider":
            return "/app/ftrider.html"
    }
}

module.exports = {
    getRedirectionForUserType
}