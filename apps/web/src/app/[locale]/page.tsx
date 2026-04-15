import { useTranslations } from "next-intl";

export default function HomePage() {
  const t = useTranslations();

  return (
    <main className="flex-1 flex flex-col items-center justify-center p-8">
      <div className="max-w-2xl text-center space-y-6">
        <h1 className="text-4xl font-bold tracking-tight">
          {t("common.appName")}
        </h1>
        <p className="text-lg text-gray-600 dark:text-gray-400">
          {t("dashboard.title")}
        </p>

        <nav className="flex gap-4 justify-center mt-8">
          <span className="px-4 py-2 rounded-lg bg-gray-100 dark:bg-gray-800 text-sm font-medium">
            {t("nav.dashboard")}
          </span>
          <span className="px-4 py-2 rounded-lg bg-gray-100 dark:bg-gray-800 text-sm font-medium">
            {t("nav.spreadsheet")}
          </span>
          <span className="px-4 py-2 rounded-lg bg-gray-100 dark:bg-gray-800 text-sm font-medium">
            {t("nav.settings")}
          </span>
        </nav>
      </div>
    </main>
  );
}
