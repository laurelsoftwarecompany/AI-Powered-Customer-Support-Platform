// ============================================================
// CONFIGURATION
// ============================================================

const API_BASE = "http://127.0.0.1:8000";

let token = localStorage.getItem("access_token");
let currentUser = null;
let currentConversationId = null;


// ============================================================
// DOM HELPERS
// ============================================================

const $ = (id) => document.getElementById(id);

function show(element) {
    element.classList.remove("hidden");
}

function hide(element) {
    element.classList.add("hidden");
}

function showMessage(element, message, type = "error") {
    element.innerHTML = `
        <div class="${type}-message">
            ${escapeHtml(message)}
        </div>
    `;
}

function escapeHtml(value) {
    if (value === null || value === undefined) {
        return "";
    }

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}


// ============================================================
// API HELPER
// ============================================================

async function apiRequest(
    endpoint,
    options = {}
) {
    const headers = {
        ...(options.headers || {})
    };

    if (options.body && !headers["Content-Type"]) {
        headers["Content-Type"] = "application/json";
    }

    if (token) {
        headers["Authorization"] = `Bearer ${token}`;
    }

    const response = await fetch(
        `${API_BASE}${endpoint}`,
        {
            ...options,
            headers
        }
    );

    let data = null;

    try {
        data = await response.json();
    } catch {
        data = null;
    }

    if (response.status === 401) {
        logout(false);

        throw new Error(
            "Your session has expired. Please login again."
        );
    }

    if (!response.ok) {
        let message = "Request failed";

        if (data) {
            if (typeof data.detail === "string") {
                message = data.detail;
            } else if (data.detail) {
                message = JSON.stringify(data.detail);
            }
        }

        throw new Error(message);
    }

    return data;
}


// ============================================================
// AUTHENTICATION
// ============================================================

$("showRegister").addEventListener(
    "click",
    () => {
        hide($("loginPage"));
        show($("registerPage"));
    }
);


$("showLogin").addEventListener(
    "click",
    () => {
        hide($("registerPage"));
        show($("loginPage"));
    }
);


// ------------------------------------------------------------
// LOGIN
// ------------------------------------------------------------

$("loginForm").addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();

        const email =
            $("loginEmail").value.trim();

        const password =
            $("loginPassword").value;

        const messageBox =
            $("authMessage");

        messageBox.innerHTML = "";

        try {

            const formData =
                new URLSearchParams();

            formData.append(
                "username",
                email
            );

            formData.append(
                "password",
                password
            );

            const response =
                await fetch(
                    `${API_BASE}/auth/login`,
                    {
                        method: "POST",
                        headers: {
                            "Content-Type":
                                "application/x-www-form-urlencoded"
                        },
                        body: formData
                    }
                );

            const data =
                await response.json();

            if (!response.ok) {
                throw new Error(
                    data.detail ||
                    "Login failed"
                );
            }

            token =
                data.access_token;

            localStorage.setItem(
                "access_token",
                token
            );

            await loadCurrentUser();

            $("loginForm").reset();

        } catch (error) {

            showMessage(
                messageBox,
                error.message
            );
        }
    }
);


// ------------------------------------------------------------
// REGISTER
// ------------------------------------------------------------

$("registerForm").addEventListener(
    "submit",
    async (event) => {

        event.preventDefault();

        const messageBox =
            $("registerMessage");

        messageBox.innerHTML = "";

        const name =
            $("registerName").value.trim();

        const email =
            $("registerEmail").value.trim();

        const password =
            $("registerPassword").value;

        const role =
            $("registerRole").value;

        try {

            const params =
                new URLSearchParams({
                    name,
                    email,
                    password,
                    role
                });

            const response =
                await fetch(
                    `${API_BASE}/users/?${params.toString()}`,
                    {
                        method: "POST"
                    }
                );

            const data =
                await response.json();

            if (!response.ok) {
                throw new Error(
                    data.detail ||
                    "Registration failed"
                );
            }

            showMessage(
                messageBox,
                "Account created successfully. You can now login.",
                "success"
            );

            $("registerForm").reset();

        } catch (error) {

            showMessage(
                messageBox,
                error.message
            );
        }
    }
);


// ============================================================
// CURRENT USER
// ============================================================

async function loadCurrentUser() {

    try {

        currentUser =
            await apiRequest(
                "/auth/me"
            );

        setupApplication();

    } catch (error) {

        console.error(
            "Failed to load current user:",
            error
        );

        logout(false);
    }
}


// ============================================================
// APPLICATION SETUP
// ============================================================

function setupApplication() {

    hide($("loginPage"));
    hide($("registerPage"));

    show($("mainApp"));

    $("userName").textContent =
        currentUser.name;

    $("userRole").textContent =
        currentUser.role;

    $("dashboardRole").textContent =
        currentUser.role;

    configureRoleUI();

    loadDashboard();

    showPage("dashboardPage");
}


function configureRoleUI() {

    const role =
        currentUser.role;

    document
        .querySelectorAll(".customer-only")
        .forEach(element => {

            if (role === "customer") {
                element.classList.remove("hidden");
            } else {
                element.classList.add("hidden");
            }
        });


    document
        .querySelectorAll(".agent-only")
        .forEach(element => {

            if (
                role === "agent" ||
                role === "admin"
            ) {
                element.classList.remove("hidden");
            } else {
                element.classList.add("hidden");
            }
        });


    document
        .querySelectorAll(".admin-only")
        .forEach(element => {

            if (role === "admin") {
                element.classList.remove("hidden");
            } else {
                element.classList.add("hidden");
            }
        });
}


// ============================================================
// LOGOUT
// ============================================================

$("logoutButton").addEventListener(
    "click",
    () => logout(true)
);


function logout(showLoginPage = true) {

    token = null;
    currentUser = null;
    currentConversationId = null;

    localStorage.removeItem(
        "access_token"
    );

    hide($("mainApp"));

    if (showLoginPage) {
        show($("loginPage"));
    }
}


// ============================================================
// NAVIGATION
// ============================================================

document
    .querySelectorAll(".nav-button")
    .forEach(button => {

        button.addEventListener(
            "click",
            () => {

                const page =
                    button.dataset.page;

                showPage(page);
            }
        );
    });


function showPage(pageId) {

    document
        .querySelectorAll(".content-page")
        .forEach(page => {
            page.classList.add("hidden");
        });


    const page =
        $(pageId);

    if (page) {
        page.classList.remove("hidden");
    }


    document
        .querySelectorAll(".nav-button")
        .forEach(button => {

            button.classList.remove(
                "active"
            );

            if (
                button.dataset.page === pageId
            ) {
                button.classList.add(
                    "active"
                );
            }
        });


    if (pageId === "dashboardPage") {
        loadDashboard();
    }

    if (pageId === "chatPage") {
        loadConversations();
    }

    if (pageId === "ticketsPage") {
        loadTickets();
    }

    if (pageId === "agentPage") {
        loadAgentDashboard();
    }

    if (pageId === "adminPage") {
        loadAdminDashboard();
    }
}


// ============================================================
// DASHBOARD
// ============================================================

async function loadDashboard() {

    try {

        let conversations = [];
        let tickets = [];

        if (currentUser.role === "customer") {

            conversations =
                await apiRequest(
                    "/conversations/my"
                );

            tickets =
                await apiRequest(
                    "/tickets/my"
                );

        } else {

            conversations =
                await apiRequest(
                    "/conversations/"
                );

            tickets =
                await apiRequest(
                    "/tickets/"
                );
        }

        $("dashboardConversations")
            .textContent =
            conversations.length;

        $("dashboardTickets")
            .textContent =
            tickets.length;

    } catch (error) {

        console.error(
            "Dashboard error:",
            error
        );
    }
}


// ============================================================
// CUSTOMER CONVERSATIONS
// ============================================================

$("newConversationButton")
    .addEventListener(
        "click",
        createConversation
    );


async function createConversation() {

    try {

        const conversation =
            await apiRequest(
                "/conversations/",
                {
                    method: "POST"
                }
            );

        currentConversationId =
            conversation.id;

        await loadConversations();

        await loadConversationMessages(
            conversation.id
        );

    } catch (error) {

        alert(
            error.message
        );
    }
}


async function loadConversations() {

    if (
        !currentUser ||
        currentUser.role !== "customer"
    ) {
        return;
    }

    const container =
        $("conversationList");

    container.innerHTML =
        `<div class="loading">
            Loading...
        </div>`;

    try {

        const conversations =
            await apiRequest(
                "/conversations/my"
            );

        if (!conversations.length) {

            container.innerHTML =
                `<p class="empty">
                    No conversations yet.
                </p>`;

            return;
        }

        container.innerHTML =
            conversations
                .map(conversation => {

                    const active =
                        conversation.id ===
                        currentConversationId
                            ? "active"
                            : "";

                    return `
                        <div
                            class="conversation-item ${active}"
                            onclick="selectConversation(${conversation.id})"
                        >

                            <strong>
                                Conversation #${conversation.id}
                            </strong>

                            <span>
                                ${escapeHtml(conversation.status)}
                            </span>

                        </div>
                    `;
                })
                .join("");

    } catch (error) {

        container.innerHTML =
            `<p class="empty">
                ${escapeHtml(error.message)}
            </p>`;
    }
}


window.selectConversation =
    async function(conversationId) {

        currentConversationId =
            conversationId;

        await loadConversations();

        await loadConversationMessages(
            conversationId
        );
    };


// ============================================================
// CONVERSATION MESSAGES
// ============================================================

async function loadConversationMessages(
    conversationId
) {

    const container =
        $("messagesContainer");

    container.innerHTML =
        `<div class="loading">
            Loading messages...
        </div>`;

    $("chatMessage").disabled = false;

    $("chatForm")
        .querySelector("button")
        .disabled = false;

    try {

        const messages =
            await apiRequest(
                `/conversations/${conversationId}/messages`
            );

        renderMessages(messages);

        $("chatStatus")
            .textContent =
            "Conversation #" +
            conversationId;

    } catch (error) {

        container.innerHTML =
            `<div class="empty-chat">
                <div>⚠️</div>
                <h3>Unable to load messages</h3>
                <p>
                    ${escapeHtml(error.message)}
                </p>
            </div>`;
    }
}


function renderMessages(messages) {

    const container =
        $("messagesContainer");

    if (!messages.length) {

        container.innerHTML =
            `<div class="empty-chat">

                <div>💬</div>

                <h3>
                    No messages yet
                </h3>

                <p>
                    Send a message to start the conversation.
                </p>

            </div>`;

        return;
    }


    container.innerHTML = "";


    messages.forEach(message => {

        const sender =
            message.sender_type;

        const wrapper =
            document.createElement("div");

        wrapper.className =
            `message ${sender === "user" ? "customer" : sender}`;

        let aiInfo = "";

        if (sender === "ai") {

            const confidence =
                Number(
                    message.confidence || 0
                );

            const confidencePercent =
                Math.round(
                    confidence * 100
                );

            const confidenceClass =
                confidence < 0.70
                    ? "warning"
                    : "success";

            aiInfo = `
                <div class="ai-info">

                    <span class="badge">
                        Intent:
                        ${escapeHtml(
                            message.intent ||
                            "unknown"
                        )}
                    </span>

                    <span class="badge ${confidenceClass}">
                        Confidence:
                        ${confidencePercent}%
                    </span>

                </div>
            `;
        }


        const senderName =
            sender === "ai"
                ? "AI Assistant"
                : sender === "customer"
                    ? "You"
                    : sender;


        wrapper.innerHTML = `

            <div class="message-bubble">

                ${escapeHtml(
                    message.content
                )}

                ${aiInfo}

            </div>

            <div class="message-meta">

                <span>
                    ${escapeHtml(senderName)}
                </span>

                <span>
                    ${formatDate(
                        message.created_at
                    )}
                </span>

            </div>
        `;


        container.appendChild(
            wrapper
        );
    });


    container.scrollTop =
        container.scrollHeight;
}


// ============================================================
// SEND CHAT MESSAGE
// ============================================================

$("chatForm")
    .addEventListener(
        "submit",
        async (event) => {

            event.preventDefault();

            if (!currentConversationId) {
                return;
            }

            const input =
                $("chatMessage");

            const button =
                $("chatForm")
                    .querySelector("button");

            const content =
                input.value.trim();

            if (!content) {
                return;
            }

            input.disabled = true;
            button.disabled = true;

            try {

                await apiRequest(
                    `/conversations/${currentConversationId}/messages`,
                    {
                        method: "POST",

                        body: JSON.stringify({
                            content
                        })
                    }
                );

                input.value = "";

                await loadConversationMessages(
                    currentConversationId
                );

                await loadConversations();

            } catch (error) {

                alert(
                    error.message
                );

            } finally {

                input.disabled = false;
                button.disabled = false;

                input.focus();
            }
        }
    );


// ============================================================
// TICKETS
// ============================================================

$("createTicketButton")
    .addEventListener(
        "click",
        () => {

            $("ticketModal")
                .classList.remove("hidden");
        }
    );


$("closeTicketModal")
    .addEventListener(
        "click",
        () => {

            $("ticketModal")
                .classList.add("hidden");
        }
    );


$("ticketForm")
    .addEventListener(
        "submit",
        createTicket
    );


async function createTicket(event) {

    event.preventDefault();

    const messageBox =
        $("ticketFormMessage");

    messageBox.innerHTML = "";

    const ticket = {

        subject:
            $("ticketSubject")
                .value
                .trim(),

        category:
            $("ticketCategory")
                .value
                .trim(),

        priority:
            $("ticketPriority")
                .value,

        description:
            $("ticketDescription")
                .value
                .trim()
    };

    try {

        await apiRequest(
            "/tickets/",
            {
                method: "POST",

                body:
                    JSON.stringify(ticket)
            }
        );

        showMessage(
            messageBox,
            "Ticket created successfully.",
            "success"
        );

        $("ticketForm")
            .reset();

        await loadTickets();

        setTimeout(
            () => {
                $("ticketModal")
                    .classList
                    .add("hidden");
            },
            800
        );

    } catch (error) {

        showMessage(
            messageBox,
            error.message
        );
    }
}


async function loadTickets() {

    const container =
        $("ticketsContainer");

    container.innerHTML =
        `<div class="loading">
            Loading tickets...
        </div>`;

    try {

        let tickets;

        if (
            currentUser.role ===
            "customer"
        ) {

            tickets =
                await apiRequest(
                    "/tickets/my"
                );

        } else {

            tickets =
                await apiRequest(
                    "/tickets/"
                );
        }


        if (!tickets.length) {

            container.innerHTML =
                `<div class="info-card">
                    <p class="empty">
                        No tickets found.
                    </p>
                </div>`;

            return;
        }


        container.innerHTML =
            tickets
                .map(renderTicketCard)
                .join("");

    } catch (error) {

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(
                    error.message
                )}
            </div>`;
    }
}


function renderTicketCard(ticket) {

    return `

        <div
            class="ticket-card"
            onclick="openTicket(${ticket.id})"
        >

            <div class="ticket-top">

                <span class="ticket-title">
                    #${ticket.id}
                    ${escapeHtml(
                        ticket.subject
                    )}
                </span>

                <span class="status ${ticket.status}">
                    ${escapeHtml(
                        ticket.status
                    )}
                </span>

            </div>


            <div class="ticket-description">

                ${escapeHtml(
                    ticket.description
                )}

            </div>


            <div class="ticket-meta">

                <span class="badge">
                    ${escapeHtml(
                        ticket.category
                    )}
                </span>

                <span class="badge">
                    Priority:
                    ${escapeHtml(
                        ticket.priority
                    )}
                </span>

                ${
                    ticket.assigned_agent_id
                        ? `
                            <span class="badge success">
                                Agent #${ticket.assigned_agent_id}
                            </span>
                        `
                        : `
                            <span class="badge warning">
                                Unassigned
                            </span>
                        `
                }

            </div>

        </div>
    `;
}


// ============================================================
// TICKET DETAILS
// ============================================================

window.openTicket =
    async function(ticketId) {

        $("ticketDetailModal")
            .classList
            .remove("hidden");

        $("ticketDetailContent")
            .innerHTML =
            `<div class="loading">
                Loading ticket...
            </div>`;

        try {

            const ticket =
                await apiRequest(
                    `/tickets/${ticketId}`
                );

            const messages =
                await apiRequest(
                    `/tickets/${ticketId}/messages`
                );

            renderTicketDetails(
                ticket,
                messages
            );

        } catch (error) {

            $("ticketDetailContent")
                .innerHTML =
                `<div class="error-message">
                    ${escapeHtml(
                        error.message
                    )}
                </div>`;
        }
    };


function renderTicketDetails(
    ticket,
    messages
) {

    $("ticketDetailTitle")
        .textContent =
        `Ticket #${ticket.id}`;


    $("ticketDetailContent")
        .innerHTML = `

            <div class="ticket-card">

                <div class="ticket-top">

                    <span class="ticket-title">
                        ${escapeHtml(
                            ticket.subject
                        )}
                    </span>

                    <span class="status ${ticket.status}">
                        ${escapeHtml(
                            ticket.status
                        )}
                    </span>

                </div>

                <p class="ticket-description">

                    ${escapeHtml(
                        ticket.description
                    )}

                </p>

                <div class="ticket-meta">

                    <span class="badge">
                        ${escapeHtml(
                            ticket.category
                        )}
                    </span>

                    <span class="badge">
                        Priority:
                        ${escapeHtml(
                            ticket.priority
                        )}
                    </span>

                    <span class="badge">
                        Agent:
                        ${
                            ticket.assigned_agent_id
                                || "Unassigned"
                        }
                    </span>

                </div>

            </div>


            <h3 style="margin: 20px 0 12px;">
                Ticket Messages
            </h3>


            <div id="ticketMessages">

                ${
                    messages.length
                        ? messages
                            .map(
                                renderTicketMessage
                            )
                            .join("")
                        : `
                            <p class="empty">
                                No messages.
                            </p>
                        `
                }

            </div>

        `;
}


function renderTicketMessage(message) {

    return `

        <div class="ticket-card">

            <div class="ticket-top">

                <strong>
                    ${escapeHtml(
                        message.sender_type
                    )}
                </strong>

                <span>
                    ${formatDate(
                        message.created_at
                    )}
                </span>

            </div>

            <p class="ticket-description">
                ${escapeHtml(
                    message.content
                )}
            </p>

        </div>

    `;
}


$("closeTicketDetailModal")
    .addEventListener(
        "click",
        () => {

            $("ticketDetailModal")
                .classList
                .add("hidden");
        }
    );


// ============================================================
// AGENT DASHBOARD
// ============================================================

async function loadAgentDashboard() {

    if (
        !currentUser ||
        (currentUser.role !== "agent" &&
         currentUser.role !== "admin")
    ) {
        return;
    }

    await Promise.allSettled([
        loadAgentStats(),
        loadUnassignedTickets(),
        loadAgentTickets(),
        loadAgentWorkload(),
        loadAgentConversations()
    ]);
}


// ------------------------------------------------------------
// AGENT STATS
// ------------------------------------------------------------

async function loadAgentStats() {

    try {

        const stats =
            await apiRequest(
                "/agents/dashboard/stats"
            );

        $("agentTotalTickets").textContent =
            stats.total_tickets ?? 0;

        $("agentOpenTickets").textContent =
            stats.open_tickets ?? 0;

        $("agentProgressTickets").textContent =
            stats.in_progress_tickets ?? 0;

        $("agentUnassignedTickets").textContent =
            stats.unassigned_tickets ?? 0;

    } catch (error) {

        console.error(
            "Agent stats error:",
            error
        );

    }
}


// ------------------------------------------------------------
// UNASSIGNED TICKETS
// ------------------------------------------------------------

async function loadUnassignedTickets() {

    const container =
        $("unassignedTicketsContainer");

    if (!container) return;

    container.innerHTML =
        `<div class="loading">
            Loading unassigned tickets...
        </div>`;

    try {

        const tickets =
            await apiRequest(
                "/agents/tickets/unassigned"
            );

        if (!tickets.length) {

            container.innerHTML =
                `<p class="empty">
                    No unassigned tickets.
                </p>`;

            return;
        }

        container.innerHTML =
            tickets
                .map(ticket => `

                    <div class="ticket-card">

                        <div class="ticket-top">

                            <span class="ticket-title">
                                #${ticket.id}
                                ${escapeHtml(ticket.subject)}
                            </span>

                            <span class="status ${ticket.status}">
                                ${escapeHtml(ticket.status)}
                            </span>

                        </div>

                        <div class="ticket-description">
                            ${escapeHtml(ticket.description)}
                        </div>

                        <div class="ticket-meta">

                            <span class="badge">
                                ${escapeHtml(ticket.category)}
                            </span>

                            <span class="badge">
                                Priority:
                                ${escapeHtml(ticket.priority)}
                            </span>

                            <button
                                class="btn-primary"
                                onclick="claimTicket(${ticket.id})"
                            >
                                Claim Ticket
                            </button>

                        </div>

                    </div>

                `)
                .join("");

    } catch (error) {

        console.error(
            "Unassigned tickets error:",
            error
        );

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(error.message)}
            </div>`;
    }
}


// ------------------------------------------------------------
// CLAIM TICKET
// ------------------------------------------------------------

window.claimTicket =
    async function(ticketId) {

        try {

            await apiRequest(
                `/agents/tickets/${ticketId}/claim`,
                {
                    method: "POST"
                }
            );

            alert(
                `Ticket #${ticketId} claimed successfully.`
            );

            await loadAgentDashboard();

        } catch (error) {

            alert(
                error.message
            );
        }
    };


// ------------------------------------------------------------
// MY TICKETS
// ------------------------------------------------------------

async function loadAgentTickets() {

    const container =
        $("agentTicketsContainer");

    if (!container) return;

    container.innerHTML =
        `<div class="loading">
            Loading...
        </div>`;

    try {

        if (currentUser.role !== "agent") {

            container.innerHTML =
                `<p class="empty">
                    Only support agents can access assigned tickets.
                </p>`;

            return;
        }

        const tickets =
            await apiRequest(
                "/agents/tickets"
            );

        if (!tickets.length) {

            container.innerHTML =
                `<p class="empty">
                    No tickets assigned.
                </p>`;

            return;
        }

        container.innerHTML =
            tickets
                .map(renderTicketCard)
                .join("");

    } catch (error) {

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(error.message)}
            </div>`;
    }
}


// ------------------------------------------------------------
// AGENT WORKLOAD
// ------------------------------------------------------------

async function loadAgentWorkload() {

    const container =
        $("agentWorkloadContainer");

    if (!container) return;

    container.innerHTML =
        `<div class="loading">
            Loading workload...
        </div>`;

    try {

        const workload =
            await apiRequest(
                "/agents/workload"
            );

        if (!workload.length) {

            container.innerHTML =
                `<p class="empty">
                    No workload data available.
                </p>`;

            return;
        }

        container.innerHTML =
            workload
                .map(agent => `

                    <div class="info-card">

                        <div class="ticket-top">

                            <strong>
                                ${escapeHtml(agent.name)}
                            </strong>

                            <span class="badge">
                                ${agent.assigned_tickets}
                                ticket(s)
                            </span>

                        </div>

                        <p>
                            ${escapeHtml(agent.email)}
                        </p>

                    </div>

                `)
                .join("");

    } catch (error) {

        console.error(
            "Workload error:",
            error
        );

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(error.message)}
            </div>`;
    }
}


// ------------------------------------------------------------
// CUSTOMER CONVERSATIONS
// ------------------------------------------------------------

async function loadAgentConversations() {

    const container =
        $("agentConversationsContainer");

    if (!container) return;

    container.innerHTML =
        `<div class="loading">
            Loading conversations...
        </div>`;

    try {

        const conversations =
            await apiRequest(
                "/agents/conversations"
            );

        if (!conversations.length) {

            container.innerHTML =
                `<p class="empty">
                    No customer conversations.
                </p>`;

            return;
        }

        container.innerHTML =
            conversations
                .map(conversation => `

                    <div
                        class="info-card"
                        style="cursor:pointer;"
                        onclick="openAgentConversation(${conversation.id})"
                    >

                        <div class="ticket-top">

                            <strong>
                                Conversation #${conversation.id}
                            </strong>

                            <span class="badge">
                                ${escapeHtml(
                                    conversation.status
                                )}
                            </span>

                        </div>

                        <p>
                            Customer ID:
                            ${conversation.customer_id}
                        </p>

                        <p>
                            Updated:
                            ${formatDate(
                                conversation.updated_at
                            )}
                        </p>

                    </div>

                `)
                .join("");

    } catch (error) {

        console.error(
            "Agent conversations error:",
            error
        );

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(error.message)}
            </div>`;
    }
}


// ------------------------------------------------------------
// OPEN AGENT CONVERSATION
// ------------------------------------------------------------

window.openAgentConversation =
    async function(conversationId) {

        try {

            const messages =
                await apiRequest(
                    `/conversations/${conversationId}/messages`
                );

            console.log(
                "Conversation messages:",
                messages
            );

            alert(
                `Conversation #${conversationId} has ${messages.length} message(s). Check the console for details.`
            );

        } catch (error) {

            alert(
                error.message
            );
        }
    };


// ------------------------------------------------------------
// REFRESH BUTTONS
// ------------------------------------------------------------

if ($("refreshAgentDashboard")) {

    $("refreshAgentDashboard")
        .addEventListener(
            "click",
            loadAgentDashboard
        );
}


if ($("refreshUnassignedTickets")) {

    $("refreshUnassignedTickets")
        .addEventListener(
            "click",
            loadUnassignedTickets
        );
}


if ($("refreshAgentTickets")) {

    $("refreshAgentTickets")
        .addEventListener(
            "click",
            loadAgentTickets
        );
}


if ($("refreshAgentConversations")) {

    $("refreshAgentConversations")
        .addEventListener(
            "click",
            loadAgentConversations
        );
}

// ============================================================
// ADMIN DASHBOARD
// ============================================================

async function loadAdminDashboard() {

    try {

        const stats =
            await apiRequest(
                "/admin/dashboard/stats"
            );

        // Backend returns:
        // stats.users.total
        // stats.users.agents
        // stats.tickets.total

        $("adminUsers")
            .textContent =
            stats.users?.total ?? 0;

        $("adminAgents")
            .textContent =
            stats.users?.agents ?? 0;

        $("adminTickets")
            .textContent =
            stats.tickets?.total ?? 0;

    } catch (error) {

        console.error(
            "Admin stats:",
            error
        );

        $("adminUsers").textContent = "0";
        $("adminAgents").textContent = "0";
        $("adminTickets").textContent = "0";
    }


    await loadAdminUsers();

    await loadAIAnalytics();
}


// ------------------------------------------------------------
// ADMIN USERS
// ------------------------------------------------------------

async function loadAdminUsers() {

    const container =
        $("adminUsersContainer");

    container.innerHTML =
        `<div class="loading">
            Loading users...
        </div>`;

    try {

        const users =
            await apiRequest(
                "/admin/users"
            );

        if (!users.length) {

            container.innerHTML =
                `<p class="empty">
                    No users found.
                </p>`;

            return;
        }


        container.innerHTML = `

            <div class="table-wrapper">

                <table>

                    <thead>

                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Role</th>
                            <th>Status</th>
                        </tr>

                    </thead>

                    <tbody>

                        ${
                            users
                                .map(
                                    user => `
                                        <tr>

                                            <td>
                                                ${user.id}
                                            </td>

                                            <td>
                                                ${escapeHtml(
                                                    user.name
                                                )}
                                            </td>

                                            <td>
                                                ${escapeHtml(
                                                    user.role
                                                )}
                                            </td>

                                            <td>

                                                ${
                                                    user.is_active
                                                        ? `
                                                            <span class="badge success">
                                                                Active
                                                            </span>
                                                        `
                                                        : `
                                                            <span class="badge danger">
                                                                Inactive
                                                            </span>
                                                        `
                                                }

                                            </td>

                                        </tr>
                                    `
                                )
                                .join("")
                        }

                    </tbody>

                </table>

            </div>
        `;

    } catch (error) {

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(
                    error.message
                )}
            </div>`;
    }
}


// ------------------------------------------------------------
// AI ANALYTICS
// ------------------------------------------------------------

async function loadAIAnalytics() {

    const container =
        $("adminAnalyticsContainer");

    container.innerHTML =
        `<div class="loading">
            Loading analytics...
        </div>`;

    try {

        const analytics =
            await apiRequest(
                "/admin/ai/analytics"
            );

        // Backend returns:
        // analytics.ai_messages.total
        // analytics.ai_messages.average_confidence
        // analytics.ai_messages.low_confidence

        $("adminAIMessages")
            .textContent =
            analytics.ai_messages?.total ?? 0;


        let intentHTML = "";

        if (
            analytics.intent_distribution
        ) {

            intentHTML =
                Object.entries(
                    analytics.intent_distribution
                )
                .map(
                    ([intent, count]) => `
                        <div
                            style="
                                display:flex;
                                justify-content:space-between;
                                padding:8px 0;
                                border-bottom:1px solid #e5e7eb;
                            "
                        >

                            <span>
                                ${escapeHtml(intent)}
                            </span>

                            <strong>
                                ${count}
                            </strong>

                        </div>
                    `
                )
                .join("");
        }


        container.innerHTML = `

            <div>

                <p style="margin-bottom:12px;">

                    <strong>
                        Average Confidence:
                    </strong>

                    ${
                        analytics.ai_messages?.average_confidence !== null &&
                        analytics.ai_messages?.average_confidence !== undefined
                            ? (
                                Number(
                                    analytics.ai_messages.average_confidence
                                ) * 100
                            ).toFixed(1) + "%"
                            : "N/A"
                    }

                </p>


                <p style="margin-bottom:18px;">

                    <strong>
                        Low Confidence Messages:
                    </strong>

                    ${
                        analytics.ai_messages?.low_confidence
                        ?? 0
                    }

                </p>


                <h3 style="margin-bottom:10px;">
                    Intent Distribution
                </h3>

                ${
                    intentHTML ||
                    `<p class="empty">
                        No AI data yet.
                    </p>`
                }

            </div>

        `;

    } catch (error) {

        container.innerHTML =
            `<div class="error-message">
                ${escapeHtml(
                    error.message
                )}
            </div>`;
    }
}


// ============================================================
// DATE FORMATTER
// ============================================================

function formatDate(value) {

    if (!value) {
        return "";
    }

    try {

        return new Date(value)
            .toLocaleString();

    } catch {

        return value;
    }
}


// ============================================================
// STARTUP
// ============================================================

async function initialize() {

    if (!token) {

        show($("loginPage"));

        hide($("registerPage"));

        hide($("mainApp"));

        return;
    }


    try {

        await loadCurrentUser();

    } catch {

        logout(false);

        show($("loginPage"));
    }
}


initialize();