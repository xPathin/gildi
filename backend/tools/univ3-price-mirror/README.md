# TypeScript Boilerplate

A clean, production-ready TypeScript project boilerplate with modern development tools and Docker support.

## 🚀 Features

- **TypeScript** - Latest TypeScript with strict configuration
- **pnpm** - Fast, disk space efficient package manager
- **dotenv** - Environment variable management
- **VSCode Debugging** - Pre-configured debugging with F5 support
- **Docker** - Multi-stage Dockerfile and Docker Compose setup
- **ESLint** - Code linting with TypeScript rules
- **Jest** - Testing framework with TypeScript support
- **Logging** - Structured logging utility
- **Configuration** - Centralized config management

## 📁 Project Structure

```
.
├── src/
│   ├── config/
│   │   └── config.ts          # Configuration management
│   ├── utils/
│   │   └── logger.ts          # Logging utility
│   ├── test/
│   │   └── setup.ts           # Test setup configuration
│   ├── index.ts               # Main application entry point
│   └── index.test.ts          # Example test file
├── .vscode/
│   ├── launch.json            # VSCode debugging configuration
│   └── settings.json          # VSCode workspace settings
├── dist/                      # Compiled JavaScript output
├── coverage/                  # Test coverage reports
├── .env.example               # Environment variables template
├── .eslintrc.js              # ESLint configuration
├── .gitignore                # Git ignore rules
├── docker-compose.yml        # Docker Compose configuration
├── Dockerfile                # Multi-stage Docker build
├── jest.config.js            # Jest testing configuration
├── package.json              # Package dependencies and scripts
├── tsconfig.json             # TypeScript configuration
└── README.md                 # This file
```

## 🛠️ Quick Start

### Prerequisites

- Node.js 18+ 
- pnpm 8+
- Docker (optional)

### Installation

1. **Clone or download this boilerplate**
2. **Install dependencies**:
   ```bash
   pnpm install
   ```

3. **Set up environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Start development**:
   ```bash
   pnpm run dev
   ```

## 🔧 Available Scripts

| Command | Description |
|---------|-------------|
| `pnpm run dev` | Start development with hot reload |
| `pnpm run build` | Build for production |
| `pnpm run start` | Start production build |
| `pnpm run test` | Run tests |
| `pnpm run test:watch` | Run tests in watch mode |
| `pnpm run lint` | Lint code |
| `pnpm run lint:fix` | Lint and fix code |
| `pnpm run clean` | Clean build directory |

## 🐞 VSCode Debugging

This project includes pre-configured VSCode debugging setup:

1. **Press F5** to start debugging
2. Set breakpoints in your TypeScript code
3. Debug configurations available:
   - **Debug TypeScript** - Debug the main application
   - **Debug TypeScript (attach)** - Attach to running process
   - **Debug Jest Tests** - Debug test files

## 🐳 Docker Support

### Quick Docker Run

```bash
# Build and run with Docker Compose
pnpm run docker:compose

# Or build and run manually
pnpm run docker:build
pnpm run docker:run
```

### Docker Compose Services

The `docker-compose.yml` includes:
- **app** - Main TypeScript application
- **db** - PostgreSQL database (commented out, uncomment if needed)
- **redis** - Redis cache (commented out, uncomment if needed)

### Production Docker Build

```bash
docker build -t typescript-boilerplate .
docker run -p 3000:3000 --env-file .env typescript-boilerplate
```

## ⚙️ Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```env
NODE_ENV=development
PORT=3000
API_URL=http://localhost:3000
LOG_LEVEL=info
CORS_ORIGIN=*
DATABASE_URL=postgresql://username:password@localhost:5432/database
```

### TypeScript Configuration

The `tsconfig.json` includes:
- Strict type checking
- ES2022 target
- Source maps for debugging
- Path mapping support

### ESLint Configuration

Pre-configured with:
- TypeScript ESLint rules
- Strict linting rules
- Auto-fix on save (VSCode)

## 🧪 Testing

### Running Tests

```bash
# Run all tests
pnpm test

# Run tests in watch mode
pnpm run test:watch

# Run tests with coverage
pnpm test -- --coverage
```

### Writing Tests

Tests are located alongside source files with `.test.ts` or `.spec.ts` extensions:

```typescript
import { main } from './index';

describe('Main Application', () => {
  it('should start without errors', async () => {
    await expect(main()).resolves.not.toThrow();
  });
});
```

## 📝 Logging

The project includes a structured logger:

```typescript
import { logger } from './utils/logger';

logger.info('Application started');
logger.error('Something went wrong', { error: new Error('details') });
logger.debug('Debug information', { data: { key: 'value' } });
```

Log levels: `error`, `warn`, `info`, `debug`

## 🚢 Production Deployment

### Build for Production

```bash
pnpm run build
pnpm start
```

### Docker Production

```bash
docker build -t typescript-boilerplate .
docker run -d -p 3000:3000 --name app typescript-boilerplate
```

### Environment Setup

For production, ensure you set:
- `NODE_ENV=production`
- Proper `DATABASE_URL`
- Secure `CORS_ORIGIN`
- Appropriate `LOG_LEVEL`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Useful Links

- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- [pnpm Documentation](https://pnpm.io/motivation)
- [Jest Testing Framework](https://jestjs.io/docs/getting-started)
- [ESLint Rules](https://eslint.org/docs/rules/)
- [Docker Documentation](https://docs.docker.com/)

---

**Happy coding! 🎉**
