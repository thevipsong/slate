import SwiftUI

struct SyncSetupView: View {
    @ObservedObject var viewModel: TodoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    private var canSubmit: Bool {
        SupabaseConfiguration(
            projectURL: viewModel.syncProjectURL,
            publishableKey: viewModel.syncPublishableKey
        ).isAllowedEndpoint
            && !viewModel.syncPublishableKey.isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("配置双端同步")
                        .font(.title2.weight(.bold))
                    Text("使用 Supabase Auth 与行级安全策略保护你的待办。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }
            }

            GroupBox("序事云同步") {
                Label(
                    "云端已配置，账户数据通过行级安全策略隔离。",
                    systemImage: "checkmark.shield.fill"
                )
                .foregroundStyle(.secondary)
                .padding(6)
            }

            GroupBox("同步账户") {
                VStack(spacing: 12) {
                    TextField("邮箱", text: $email)
                        .textFieldStyle(.roundedBorder)
                    SecureField("密码（至少 6 位）", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(6)
            }

            HStack {
                Button("注册账户") {
                    viewModel.configureAndAuthenticateSync(
                        email: email,
                        password: password,
                        createAccount: true
                    )
                    dismiss()
                }
                .disabled(!canSubmit || viewModel.isSyncing)

                Spacer()

                Button("登录并同步") {
                    viewModel.configureAndAuthenticateSync(
                        email: email,
                        password: password,
                        createAccount: false
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || viewModel.isSyncing)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
