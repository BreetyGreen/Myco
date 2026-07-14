using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;

namespace Myco.Views;

public partial class HomeView : UserControl
{
    public HomeView()
    {
        InitializeComponent();
        AppStore.I.StateChanged += () => Dispatcher.Invoke(Rebuild);
        Theme.Changed += () => Dispatcher.Invoke(Rebuild);   // Badge/CountBrush 需按新主题重算
        Rebuild();
    }

    private void Rebuild()
    {
        var s = AppStore.I;

        Summary.Inlines.Clear();
        Brush T(string key) => (Brush)Application.Current.Resources[key];
        Summary.Inlines.Add(new Run("检测到 ") { Foreground = T("Text2") });
        Summary.Inlines.Add(new Run($"{s.InstalledCount} 个 agent")
            { Foreground = T("Text"), FontWeight = System.Windows.FontWeights.SemiBold });
        Summary.Inlines.Add(new Run("，约 ") { Foreground = T("Text2") });
        Summary.Inlines.Add(new Run($"{s.TotalSessions} 段会话")
            { Foreground = T("Text"), FontWeight = System.Windows.FontWeights.SemiBold });
        Summary.Inlines.Add(new Run(" 可归档与接力。") { Foreground = T("Text2") });

        StatAgents.Text = s.InstalledCount.ToString();
        StatSessions.Text = s.TotalSessions.ToString();
        StatSkills.Text = s.Skills.Count.ToString();

        AgentsList.ItemsSource = null;
        AgentsList.ItemsSource = s.Agents;
    }

    private void OnGoShare(object sender, System.Windows.RoutedEventArgs e) => AppStore.I.SetTab("share");
    private void OnGoRelay(object sender, System.Windows.RoutedEventArgs e) => AppStore.I.SetTab("relay");
}
