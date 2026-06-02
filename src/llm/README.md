# Neurx LLM Extensions System

The LLM Extensions System provides comprehensive integration with language models, including multi-provider support, token management, and prompt templating.

## Overview

The LLM extensions system provides:
- Multi-provider LLM support (OpenAI, Anthropic, Google, etc.)
- Prompt templates with variable substitution
- Token counting and budget management
- Function calling and tool integration
- Streaming responses
- Cost tracking and optimization
- Request caching and rate limiting

## Core Components

### LLM Providers

```cpp
enum class LLMProviderType {
    OpenAI,        // ChatGPT, GPT-4
    Anthropic,     // Claude
    Google,        // Gemini, PaLM
    Meta,          // Llama
    LocalLLM,      // Local models
    Custom         // Custom provider
};
```

### Model Configuration

```cpp
struct ModelConfig {
    QString modelId;               // Model identifier
    LLMProviderType provider;
    
    int contextWindow = 4096;      // Max tokens
    int maxTokens = 2048;          // Max output
    
    float temperature = 0.7f;      // Creativity
    float topP = 0.9f;             // Nucleus sampling
    
    float costPer1kInputTokens;    // Pricing
    float costPer1kOutputTokens;
    
    bool supportsStreaming = true;
    bool supportsFunctions = false;
    bool supportsVision = false;
};
```

### Messages and Roles

```cpp
enum class PromptRole {
    System,      // System instructions
    User,        // User message
    Assistant,   // Assistant response
    Function     // Function result
};

struct Message {
    PromptRole role;
    QString content;
    QString name;                  // Function name
};
```

## Usage Examples

### Provider Registration

```cpp
// Register OpenAI provider
ProviderConfig openaiConfig;
openaiConfig.provider = LLMProviderType::OpenAI;
openaiConfig.apiKey = "sk-...";
openaiConfig.apiBaseUrl = "https://api.openai.com/v1";

llm->registerProvider(openaiConfig, [](bool success) {
    qDebug() << "Provider registered:" << success;
});

// Get available providers
auto providers = llm->getAvailableProviders();
```

### Model Management

```cpp
// Get available models
auto models = llm->getAvailableModels(LLMProviderType::OpenAI);
for (const auto &model : models) {
    qDebug() << "Model:" << model.modelName
             << "Context:" << model.contextWindow;
}

// Register custom model
ModelConfig customModel;
customModel.modelId = "my-model";
customModel.modelName = "Custom Model";
customModel.provider = LLMProviderType::Custom;
customModel.contextWindow = 8192;

llm->registerCustomModel(customModel, [](bool success) {
    qDebug() << "Custom model registered";
});

// Set default model
llm->setDefaultModel("my-model");
auto model = llm->getDefaultModel();
```

### Text Generation

```cpp
// Simple completion
LLMRequest request;
request.prompt = "Write a haiku about programming";
request.maxTokens = 100;

llm->generateCompletion(request, [](const LLMResponse &response) {
    if (response.success) {
        qDebug() << "Generated:" << response.content;
        qDebug() << "Tokens used:" << response.totalTokens;
        qDebug() << "Cost:" << response.cost;
    } else {
        qDebug() << "Error:" << response.error;
    }
});

// Summarization
llm->summarizeText("Long article text here...", 300, 
    [](const LLMResponse &response) {
        qDebug() << "Summary:" << response.content;
    });

// Translation
llm->translateText("Hello, world!", "Spanish",
    [](const LLMResponse &response) {
        qDebug() << "Translated:" << response.content;
    });
```

### Conversation/Chat

```cpp
// Multi-turn conversation
QVector<Message> messages;

Message systemMsg;
systemMsg.role = PromptRole::System;
systemMsg.content = "You are a helpful assistant.";
messages.append(systemMsg);

Message userMsg;
userMsg.role = PromptRole::User;
userMsg.content = "What is machine learning?";
messages.append(userMsg);

ModelConfig model = llm->getDefaultModel();

llm->chat(messages, model, [&messages](const LLMResponse &response) {
    if (response.success) {
        Message assistantMsg;
        assistantMsg.role = PromptRole::Assistant;
        assistantMsg.content = response.content;
        messages.append(assistantMsg);
        
        qDebug() << "Assistant:" << response.content;
    }
});
```

### Streaming Responses

```cpp
// Stream generation
LLMRequest request;
request.prompt = "Write a story";
request.stream = true;

QString streamId = llm->generateStreamingCompletion(request,
    [](const StreamChunk &chunk) {
        if (chunk.isFirst) {
            qDebug() << "Starting stream...";
        }
        
        qDebug() << "Chunk:" << chunk.content;
        
        if (chunk.isLast) {
            qDebug() << "Stream completed";
        }
    });

// Cancel stream if needed
llm->cancelStreaming(streamId, [](bool success) {
    qDebug() << "Stream cancelled";
});
```

### Prompt Templates

```cpp
// Create template
PromptTemplate template_;
template_.name = "Code Review";
template_.template = "Review this code:\n{{code}}\n\nFocus on {{aspect}}";
template_.variables = {"code", "aspect"};
template_.requiredVariables = {"code", "aspect"};

auto templateId = llm->createTemplate(template_, [](bool success) {
    qDebug() << "Template created";
});

// Use template
PromptTemplate retrieved = llm->getTemplate(templateId);

PromptVariables vars;
vars.variables["code"] = "int main() { return 0; }";
vars.variables["aspect"] = "performance";

QString rendered = llm->renderTemplate(retrieved, vars);

llm->generateFromTemplate(retrieved, vars, 
    [](const LLMResponse &response) {
        qDebug() << "Review:" << response.content;
    });

// List templates
auto templates = llm->listTemplates();

// Update template
retrieved.template = "Updated template";
llm->updateTemplate(templateId, retrieved, [](bool success) {
    qDebug() << "Template updated";
});

// Delete template
llm->deleteTemplate(templateId, [](bool success) {
    qDebug() << "Template deleted";
});
```

### Token Management

```cpp
// Estimate tokens
int tokens = llm->estimateTokens("How many tokens in this text?");
qDebug() << "Estimated tokens:" << tokens;

// Set token budget
TokenBudget budget;
budget.dailyLimit = 100000;
budget.monthlyLimit = 2000000;
budget.monthlyBudget = 50.0f;

llm->setTokenBudget(budget, [](bool success) {
    qDebug() << "Budget set";
});

// Check budget
if (llm->hasTokenBudget(5000)) {
    qDebug() << "Enough tokens available";
}

// Get budget
auto currentBudget = llm->getTokenBudget();
qDebug() << "Daily used:" << currentBudget.dailyUsed;

// Get token history
auto history = llm->getTokenHistory(7);  // Last 7 days
for (const auto &usage : history) {
    qDebug() << "Usage:" << usage.totalTokens << "tokens";
}

// Get usage
auto usage = llm->getTokenUsage();
qDebug() << "Total tokens used:" << usage.totalTokens;
```

### Cost Tracking

```cpp
// Estimate cost
LLMRequest request;
request.prompt = "Test prompt";

float cost = llm->estimateCost(request);
qDebug() << "Estimated cost: $" << cost;

// Get total cost
float total = llm->getTotalCost();
qDebug() << "Total spent: $" << total;

// Get cost breakdown
auto breakdown = llm->getCostBreakdown();
qDebug() << "Total requests:" << breakdown["totalRequests"];
qDebug() << "Total tokens:" << breakdown["totalTokens"];
```

### Function Calling

```cpp
// Define function
FunctionDefinition function;
function.functionId = "get_weather";
function.name = "get_weather";
function.description = "Get weather for a location";

FunctionParameter locationParam;
locationParam.name = "location";
locationParam.type = FunctionParameterType::String;
locationParam.required = true;
locationParam.description = "City name";

function.parameters.append(locationParam);

// Register function
llm->registerFunction(function, [](bool success) {
    qDebug() << "Function registered";
});

// Generate with function calling
LLMRequest request;
request.prompt = "What's the weather in London?";

QVector<FunctionDefinition> functions;
functions.append(function);

llm->generateWithFunctions(request, functions, [llm](const LLMResponse &response) {
    // LLM decides to call function
    FunctionCall call;
    call.toolCallId = "call-1";
    call.functionName = "get_weather";
    call.arguments["location"] = "London";
    
    llm->executeFunctionCall(call, [](const QVariant &result) {
        qDebug() << "Function result:" << result;
    });
});

// Get registered functions
auto functions = llm->getRegisteredFunctions();
qDebug() << "Registered functions:" << functions.size();

// Unregister function
llm->unregisterFunction("get_weather", [](bool success) {
    qDebug() << "Function unregistered";
});
```

### Embeddings

```cpp
// Generate single embedding
llm->generateEmbedding("Sample text", "text-embedding-ada-002",
    [](const QVector<float> &embedding) {
        qDebug() << "Embedding size:" << embedding.size();
    });

// Generate multiple embeddings
QStringList texts = {"Text 1", "Text 2", "Text 3"};

llm->generateEmbeddings(texts, "text-embedding-ada-002",
    [](const QVector<QVector<float>> &embeddings) {
        for (int i = 0; i < embeddings.size(); ++i) {
            qDebug() << "Embedding" << i << "size:" << embeddings[i].size();
        }
    });

// Compute similarity
float similarity = llm->computeCosineSimilarity(embedding1, embedding2);
qDebug() << "Similarity:" << similarity;  // 0.0 to 1.0
```

### Configuration

```cpp
// Set default parameters
llm->setDefaultParameters(0.8f, 0.95f, 50);  // temp, topP, topK

// Get default parameters
auto params = llm->getDefaultParameters();
qDebug() << "Temperature:" << params["temperature"];

// Set system prompt
llm->setSystemPrompt("You are a helpful coding assistant.");

// Get system prompt
auto prompt = llm->getSystemPrompt();

// Set rate limit
llm->setRateLimit(100);  // Requests per minute

// Get current rate
int rate = llm->getCurrentRequestRate();
```

### Caching and Optimization

```cpp
// Enable caching
llm->enableRequestCaching(true);

// Get cached response
auto cached = llm->getCachedResponse("What is Python?");
if (!cached.responseId.isEmpty()) {
    qDebug() << "Using cached response";
}

// Clear cache
llm->clearCache([](bool success) {
    qDebug() << "Cache cleared";
});

// Enable optimization
llm->enableResponseOptimization(true);
```

### Error Handling and Retry

```cpp
// Enable auto-retry
llm->enableAutoRetry(3, 1000);  // 3 retries, 1s backoff

// Get last error
QString error = llm->getLastError();
if (!error.isEmpty()) {
    qDebug() << "Last error:" << error;
}

// Retry last request
llm->retryLastRequest([](const LLMResponse &response) {
    qDebug() << "Retry result:" << response.success;
});
```

### Statistics and Monitoring

```cpp
// Get request statistics
auto reqStats = llm->getRequestStatistics();
qDebug() << "Total requests:" << reqStats["totalRequests"];

// Get performance metrics
auto perf = llm->getPerformanceMetrics();
qDebug() << "Avg latency:" << perf["averageLatency"] << "ms";

// Get model usage
auto modelStats = llm->getModelUsageStats();
qDebug() << "Custom models:" << modelStats["customModels"];

// Get provider health
auto health = llm->getProviderHealth();
for (auto it = health.begin(); it != health.end(); ++it) {
    qDebug() << "Provider:" << it.key() << "Status:" << it.value();
}

// Get service status
QString status = llm->getServiceStatus();
qDebug() << "Service:" << status;
```

## Signals and Events

```cpp
connect(llm.get(), &LLMExtensions::generationCompleted,
    [](const LLMResponse &response) {
        qDebug() << "Generation completed";
    });

connect(llm.get(), &LLMExtensions::streamChunkReceived,
    [](const StreamChunk &chunk) {
        qDebug() << "Stream chunk:" << chunk.content;
    });

connect(llm.get(), &LLMExtensions::tokenUsageRecorded,
    [](const TokenUsage &usage) {
        qDebug() << "Tokens used:" << usage.totalTokens;
    });

connect(llm.get(), &LLMExtensions::functionCalled,
    [](const FunctionCall &call) {
        qDebug() << "Function called:" << call.functionName;
    });

connect(llm.get(), &LLMExtensions::errorOccurred,
    [](const QString &error) {
        qDebug() << "Error:" << error;
    });

connect(llm.get(), &LLMExtensions::rateLimitReached,
    []() {
        qDebug() << "Rate limit reached";
    });
```

## Best Practices

1. **Use templates** - Pre-define common prompts
2. **Track tokens** - Monitor token usage for cost control
3. **Set budgets** - Prevent unexpected costs
4. **Handle errors** - Implement retry logic
5. **Use streaming** - For long-running generations
6. **Cache responses** - Reduce API calls
7. **Monitor providers** - Check health regularly
8. **Test costs** - Validate pricing before deployment
9. **Batch requests** - Use embeddings for multiple texts
10. **Rate limiting** - Respect provider limits

## Architecture

The LLM extensions use:
- **Multi-provider pattern** - Support various LLM providers
- **Template pattern** - Reusable prompts
- **Factory pattern** - Model creation
- **Streaming** - Non-blocking long responses
- **Caching** - Performance optimization
- **Token tracking** - Cost management
- **Function calling** - Tool integration
- **Async callbacks** - Non-blocking operations
- **Signal/slot events** - Observer pattern
- **Mutex protection** - Thread safety
