#pragma once
#include "doof_runtime.hpp"
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace doof_uikit {

class NativeView {
public:
    static std::shared_ptr<NativeView> container();
    static std::shared_ptr<NativeView> scroll();
    static std::shared_ptr<NativeView> spacer();
    static std::shared_ptr<NativeView> text(const std::string& value);
    static std::shared_ptr<NativeView> button(
        const std::string& title, const std::string& symbol, doof::callback<void()> action);
    static std::shared_ptr<NativeView> textEditor(
        const std::string& value, double fontSize, int32_t tabWidth, bool autoIndent,
        doof::callback<void(std::string)> change,
        doof::callback<void(int32_t, int32_t)> selectionChange);
    ~NativeView();
    void append(std::shared_ptr<NativeView> child);
    void detach();
    void dispose();
    void setFrame(double x, double y, double width, double height);
    void setDocumentSize(double width, double height);
    double measureWidth(const std::optional<double>& maxWidth, const std::optional<double>& maxHeight);
    double measureHeight(const std::optional<double>& maxWidth, const std::optional<double>& maxHeight);
    void setText(const std::string& value);
    void setEnabled(bool value);
    void setHidden(bool value);
    void setAccessibility(const std::string& label, const std::string& hint, const std::string& identifier);
    void setTextStyle(double size, bool semibold, bool secondary);
    std::string textEditorText();
    void setTextEditorText(const std::string& value);
    void setTextEditorHighlights(
        const std::shared_ptr<std::vector<int32_t>>& starts,
        const std::shared_ptr<std::vector<int32_t>>& lengths,
        const std::shared_ptr<std::vector<int32_t>>& styles);
    int32_t textEditorSelectionStart();
    int32_t textEditorSelectionLength();
    void setTextEditorSelection(int32_t start, int32_t length, bool reveal);

private:
    friend class NativeScreen;
    NativeView();
    struct Impl;
    std::shared_ptr<Impl> impl_;
};

class NativeScreen {
public:
    static std::shared_ptr<NativeScreen> create(
        const std::string& title,
        std::shared_ptr<NativeView> root,
        const std::shared_ptr<std::vector<std::string>>& leadingTitles,
        const std::shared_ptr<std::vector<std::string>>& leadingSymbols,
        const std::shared_ptr<std::vector<doof::callback<void()>>>& leadingActions,
        const std::shared_ptr<std::vector<std::string>>& trailingTitles,
        const std::shared_ptr<std::vector<std::string>>& trailingSymbols,
        const std::shared_ptr<std::vector<doof::callback<void()>>>& trailingActions,
        doof::callback<void(double, double)> layout);
    ~NativeScreen();
    void run();
    void presentAlert(const std::string& title, const std::string& message);
    void openDocument(
        const std::shared_ptr<std::vector<std::string>>& typeIdentifiers,
        doof::callback<void(std::optional<std::string>)> handler);
    void exportDocument(
        const std::string& path, const std::string& suggestedName,
        doof::callback<void(bool)> handler);

private:
    NativeScreen();
    struct Impl;
    std::shared_ptr<Impl> impl_;
};

} // namespace doof_uikit
